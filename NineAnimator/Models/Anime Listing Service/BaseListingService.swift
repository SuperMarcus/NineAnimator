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

class BaseListingService: SessionDelegate {
    var identifier: String { return "" }
    
    var persistedProperties: [String: Any] {
        get {
            do {
                let fs = FileManager.default
                
                // Store the properties under the application support directory
                let applicationSupportDirectory = try fs.url(
                    for: .applicationSupportDirectory,
                    in: .allDomainsMask,
                    appropriateFor: nil,
                    create: true
                )
                let propertyPersistentFile = applicationSupportDirectory
                    .appendingPathComponent("\(identifier).plist")
                
                // Unserialize if the file exists
                if (try? propertyPersistentFile.checkResourceIsReachable()) == true {
                    let persistedPropertiesData = try Data(contentsOf: propertyPersistentFile)
                    if let decodedProperties = try PropertyListSerialization.propertyList(
                            from: persistedPropertiesData,
                            options: [],
                            format: nil
                        ) as? [String: Any] {
                        return decodedProperties
                    }
                }
            } catch { Log.error("Cannot read listing service state: %@", error) }
            return [:]
        }
        set {
            do {
                let fs = FileManager.default
                
                // Store the properties under the application support directory
                let applicationSupportDirectory = try fs.url(
                    for: .applicationSupportDirectory,
                    in: .allDomainsMask,
                    appropriateFor: nil,
                    create: true
                )
                let propertyPersistentFile = applicationSupportDirectory
                    .appendingPathComponent("\(identifier).plist")
                
                // Write properties to file
                try PropertyListSerialization
                    .data(fromPropertyList: newValue, format: .binary, options: 0)
                    .write(to: propertyPersistentFile)
            } catch { Log.error("Cannot write listing service state: %@", error) }
        }
    }
    
    unowned var parent: NineAnimator
    
    private(set) lazy var session: Alamofire.SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        return SessionManager(configuration: configuration, delegate: self)
    }()
    
    required init(_ parent: NineAnimator) {
        self.parent = parent
        super.init()
    }
    
    /// Making a promisified request
    func request(_ url: URL, method: HTTPMethod = .get, data: Data? = nil, headers: HTTPHeaders = [:]) -> NineAnimatorPromise<Data> {
        return NineAnimatorPromise.firstly {
            var request = try URLRequest(url: url, method: method)
            headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
            request.httpBody = data
            return request
        } .thenPromise {
            request in
            NineAnimatorPromise {
                callback in
                self.session.request(request).responseData {
                    response in
                    switch response.result {
                    case .success(let value): callback(value, nil)
                    case .failure(let error): callback(nil, error)
                    }
                }
            }
        }
    }
    
    /// Retrieve the episode number from the assigned episode name
    ///
    /// Typically the first portion of the episode name contains the
    /// episode number.
    func suggestEpisodeNumber(from name: String) -> Int {
        if let nameFirstPortion = name.split(separator: " ").first,
            let episodeNumber = Int(String(nameFirstPortion)) {
            return episodeNumber
        } else {
            Log.info("Episode name \"%\" does not suggest an episode number. Using 1 as the progress.", name)
            return 1
        }
    }
    
    /// A template onRegister method
    func onRegister() { }
}
