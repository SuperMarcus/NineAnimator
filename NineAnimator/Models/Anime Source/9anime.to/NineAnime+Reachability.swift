//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
//
//  NineAnimator is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  NineAnimator is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with NineAnimator.  If not, see <http://www.gnu.org/licenses/>.
//

import Alamofire
import Foundation

// Implementations for 9anime endpoint switching
extension NASourceNineAnime/*: Alamofire.RequestAdapter*/ {
    var possibleHosts: [String] {
        [
            // A list of hosts that 9anime uses
            "9anime.ru",
            "www2.9anime.to",
            "9anime.live",
            "9anime.nl",
            "9anime.one"
        ]
    }
    
    func determineEndpoint(_ url: URL) -> NineAnimatorPromise<URL> {
        Log.info("[9anime] Looking for a new valid 9anime host")
        return NineAnimatorPromise<Bool>.queue(listOfPromises: possibleHosts.map {
            endpoint -> NineAnimatorPromise<Bool> in
            guard let endpointUrl = URL(string: "https://\(endpoint)") else {
                return .fail(NineAnimatorError.urlError)
            }
            return NineAnimatorPromise<Bool> { callback in
                super.request(browse: endpointUrl, headers: [:]) {
                    value, _ in
                    if value == nil {
                        Log.info("[9anime] Endpoint '%@' is unavailable", endpoint)
                        callback(false, nil)
                    } else {
                        Log.info("[9anime] Endpoint '%@' is available", endpoint)
                        callback(true, nil)
                    }
                }
            }
        }).then {
            listOfEndpoints in
            guard let index = listOfEndpoints.firstIndex(of: true) else {
                Log.error("[9anime] No available host found for 9anime")
                throw NineAnimatorError.providerError("Unable to find any available 9anime server")
            }
            self._currentHost = self.possibleHosts[index]
            Log.info("[9anime] Switching to host '%@'", self._currentHost)
            // Return the new processed url
            return self._process(url: url)
        }
    }
    
    func _process(url: URL) -> URL {
        guard var urlBuilder = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Log.error("[9anime] Unable to process 9anime url. Passing original URL.")
            return url
        }
        
        // Replace the host with the current endpoint
        if let host = url.host, possibleHosts.contains(host) {
            urlBuilder.host = _currentHost
        }
        
        // Enforce HTTPS
        urlBuilder.scheme = "https"
        
        // Generate url
        guard let generatedUrl = urlBuilder.url else {
            Log.error("[9anime] Unable to generate 9anime url. Passing original URL.")
            return url
        }
        return generatedUrl
    }
    
//    func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
//        var newRequest = urlRequest
//        if let url = urlRequest.url {
//            newRequest.url = _process(url: url)
//        }
//        return newRequest
//    }
}
