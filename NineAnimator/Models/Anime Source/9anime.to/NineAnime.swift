//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2020 Marcus Zhou. All rights reserved.
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

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class NASourceNineAnime: BaseSource, Source {
    let name: String = "9anime.ru"
    
    var aliases: [String] { [] }
    
    override var endpoint: String { "https://\(_currentHost)" }
    
#if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "9anime Site Icon") }
#elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "9anime Site Icon") }
#endif
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.romaji
    }
    
    var siteDescription: String {
        "9anime is a popular free anime streaming website and one of the best supported anime sources in NineAnimator."
    }
    
    override var isEnabled: Bool {
        true
    }
    
    lazy var _currentHost: String = possibleHosts.first!
    var _endpointDeterminingTask: NineAnimatorAsyncTask? // Avoid multiple concurrent requests
    
    override init(with parent: NineAnimator) {
        super.init(with: parent)
        addMiddleware(NASourceNineAnime._verificationDetectionMiddleware)
        addMiddleware(NASourceNineAnime._ipBlockDetectionMiddleware)
        addMiddleware(NASourceNineAnime._contentNotFoundMiddleware)
    }
    
    override func canHandle(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return possibleHosts.contains(host)
    }
    
    // Override the request methods to intercept endpoint change
    
    override func request(
            browse url: URL,
            method: HTTPMethod = .get,
            headers: [String: String],
            parameters: Parameters? = nil,
            encoding: ParameterEncoding = URLEncoding.default,
            completion handler: @escaping NineAnimatorCallback<String>
        ) -> NineAnimatorAsyncTask? {
        let task = AsyncTaskContainer()
        task += super.request(
            browse: _process(url: url),
            method: method,
            headers: headers,
            parameters: parameters,
            encoding: encoding
        ) {
            value, error in // Not using weak self here because Source instances persist
            // If the result is valid, pass it on to the handler
            if let value = value { return handler(value, nil) }
            
            // Return error directly
            if error is NineAnimatorError.AuthenticationRequiredError {
                return handler(value, error)
            }
            
            Log.info("[9anime] Request failed with an error. Trying to resolve a different endpoint.")
            // Trying to determine a new endpoint if an error occurred
            self._endpointDeterminingTask = self.determineEndpoint(url)
                .error { _ in handler(nil, error) }
                .finally {
                    [weak task] newUrl in
                    guard let task = task else { return }
                    Log.info("[9anime] New endpoint found, resuming original task.")
                    task += super.request(browse: newUrl, headers: headers, completion: handler)
                }
        }
        return task
    }
    
    override func request(
            ajax url: URL,
            headers: [String: String],
            completion handler: @escaping NineAnimatorCallback<NSDictionary>
        ) -> NineAnimatorAsyncTask? {
        let task = AsyncTaskContainer()
        task += super.request(ajax: _process(url: url), headers: headers) {
            value, error in // Not using weak self here because Source instances persist
            // If the result is valid, pass it on to the handler
            if let value = value { return handler(value, nil) }
            
            // If the website requires authentication
            if error is NineAnimatorError.AuthenticationRequiredError {
                return handler(nil, error)
            }
            
            Log.info("[9anime] Request failed with an error. Trying to resolve a different endpoint.")
            // Trying to determine a new endpoint if an error occurred
            self._endpointDeterminingTask = self.determineEndpoint(url)
                .error { _ in handler(nil, error) }
                .finally {
                    [weak task] newUrl in
                    guard let task = task else { return }
                    Log.info("[9anime] New endpoint found, resuming original task.")
                    task += super.request(ajax: newUrl, headers: headers, completion: handler)
                }
        }
        return task
    }
    
    func signedRequest(
        browse path: String,
        parameters: [URLQueryItem] = [:],
        with headers: [String: String] = [:],
        completion handler: @escaping NineAnimatorCallback<String>
        ) -> NineAnimatorAsyncTask? {
        signedRequest(
            browse: endpointURL.appendingPathComponent(path),
            parameters: parameters,
            with: headers,
            completion: handler
        )
    }
    
    func signedRequest(
            browse url: URL,
            parameters: [URLQueryItem] = [:],
            with headers: [String: String] = [:],
            completion handler: @escaping NineAnimatorCallback<String>
        ) -> NineAnimatorAsyncTask? {
        request(browse: signRequestURL(url, withParameters: parameters), headers: headers, completion: handler)
    }
    
    func signedRequest(
            ajax path: String,
            parameters: [URLQueryItem] = [:],
            with headers: [String: String] = [:],
            completion handler: @escaping NineAnimatorCallback<NSDictionary>
        ) -> NineAnimatorAsyncTask? {
        // Forward the call
        return signedRequest(
            ajax: endpointURL.appendingPathComponent(path),
            parameters: parameters,
            with: headers,
            completion: handler
        )
    }
    
    func signedRequest(
            ajax url: URL,
            parameters: [URLQueryItem] = [:],
            with headers: [String: String] = [:],
            completion handler: @escaping NineAnimatorCallback<NSDictionary>
        ) -> NineAnimatorAsyncTask? {
        // Additional verification headers
        let modifiedRequestHeaders = headers.merging([
            "Accept": "application/json, text/javascript, */*; q=0.01"
        ]) { override, _ in override }
        
        // Forward the call
        return request(
            ajax: signRequestURL(url, withParameters: parameters),
            headers: modifiedRequestHeaders,
            completion: handler
        )
    }
    
    /// Make a signed request with path related to the endpoint
    func signedRequest(
            ajaxString path: String,
            parameters: [URLQueryItem] = [:],
            headers: [String: String] = [:],
            completion handler: @escaping NineAnimatorCallback<String>
        ) -> NineAnimatorAsyncTask? {
        // Forward the call
        return signedRequest(
            ajaxString: endpointURL.appendingPathComponent(path),
            parameters: parameters,
            headers: headers,
            completion: handler
        )
    }
    
    /// Make a signed request
    func signedRequest(
            ajaxString url: URL,
            parameters: [URLQueryItem] = [],
            headers: [String: String] = [:],
            completion handler: @escaping NineAnimatorCallback<String>
        ) -> NineAnimatorAsyncTask? {
        // Call the original request function with modified URL
        return request(
            ajaxString: signRequestURL(url, withParameters: parameters),
            headers: headers,
            completion: handler
        )
    }
    
    override func request(
            ajaxString url: URL,
            headers: [String: String],
            completion handler: @escaping NineAnimatorCallback<String>
        ) -> NineAnimatorAsyncTask? {
        let task = AsyncTaskContainer()
        task += super.request(ajaxString: _process(url: url), headers: headers) {
            value, error in // Not using weak self here because Source instances persist
            // If the result is valid, pass it on to the handler
            if let value = value { return handler(value, nil) }
            
            // If the website requires authentication
            if error is NineAnimatorError.AuthenticationRequiredError {
                return handler(nil, error)
            }
            
            Log.info("[9anime] Request failed with an error: %@", String(describing: error))
            
            // Only try to resolve new hosts when in foreground
            if AppDelegate.shared?.isActive == true {
                Log.info("[9anime] Trying to resolve a new host for 9anime...")
                // Trying to determine a new endpoint if an error occurred
                self._endpointDeterminingTask = self.determineEndpoint(url)
                    .error { _ in handler(nil, error) }
                    .finally {
                        [weak task] newUrl in
                        guard let task = task else { return }
                        Log.info("[9anime] New endpoint found, resuming original task.")
                        task += super.request(ajaxString: newUrl, headers: headers, completion: handler)
                    }
            } else { handler(nil, error) }
        }
        return task
    }
}
