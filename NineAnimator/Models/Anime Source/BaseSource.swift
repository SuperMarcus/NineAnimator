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

/**
 Class BaseSource: all the network functions that the subclasses will ever need
 */
class BaseSource: SessionDelegate {
    let parent: NineAnimator
    
    var endpoint: String { return "" }
    
    var endpointURL: URL { return URL(string: endpoint)! }
    
    var _cfResolverTimer: Timer?
    var _cfPausedTasks = [Alamofire.RequestRetryCompletion]()
    
    /// The session used to create ajax requests
    lazy var retriverSession: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpAdditionalHeaders = [
            "User-Agent": sessionUserAgent,
            "X-Requested-With": "XMLHttpRequest"
        ]
        let manager = SessionManager(configuration: configuration, delegate: self)
        manager.retrier = self
        return manager
    }()
    
    /// The session used to create browsing requests
    lazy var browseSession: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpAdditionalHeaders = [
            "User-Agent": sessionUserAgent
        ]
        let manager = SessionManager(configuration: configuration, delegate: self)
        manager.retrier = self
        return manager
    }()
    
    var sessionUserAgent: String {
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.1 Safari/605.1.15"
    }
    
    init(with parent: NineAnimator) {
        self.parent = parent
    }
    
    /**
     Test if the url belongs to this source
     
     The default logic to test if the url belongs to this source is to see if
     the host name of this url ends with the source's endpoint.
     
     Subclasses should override this method if the anime watching url is
     different from the enpoint url.
     */
    func canHandle(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return endpoint.hasSuffix(host)
    }
    
    /// Default recommendServer(for:) implementation
    ///
    /// The default recommendation behavior is to find the first streaming
    /// source whose name is registered in the default VideoProviderRegistry
    func recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
        let availableServers = anime.servers
        return availableServers.first {
            VideoProviderRegistry.default.provider(for: $0.value) != nil
        }?.key
    }
    
    func request(browse url: URL, headers: [String: String], completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        return browseSession
            .request(url, headers: headers)
            .validate(BaseSource._cloudflareWAFVerificationMiddleware)
            .responseString {
                switch $0.result {
                case .failure(let error):
                    Log.error("request to %@ failed - %@", url, error)
                    handler(nil, error)
                case .success(let value):
                    handler(value, nil)
                }
            }
    }
    
    func request(ajax url: URL, headers: [String: String], completion handler: @escaping NineAnimatorCallback<NSDictionary>) -> NineAnimatorAsyncTask? {
        return retriverSession
            .request(url, headers: headers)
            .validate(BaseSource._cloudflareWAFVerificationMiddleware)
            .responseJSON {
                response in
                switch response.result {
                case .failure(let error):
                    Log.error("request to %@ failed - %@", url, error)
                    handler(nil, error)
                case .success(let value as NSDictionary):
                    handler(value, nil)
                default:
                    Log.error("Unable to convert response value to NSDictionary")
                    handler(nil, NineAnimatorError.responseError("Invalid Response"))
                }
            }
    }
    
    func request(ajaxString url: URL, headers: [String: String], completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        return retriverSession
            .request(url, headers: headers)
            .validate(BaseSource._cloudflareWAFVerificationMiddleware)
            .responseString {
                response in
                switch response.result {
                case .failure(let error):
                    Log.error("request to %@ failed - %@", url, error)
                    handler(nil, error)
                case .success(let value):
                    handler(value, nil)
                }
            }
    }
    
    func request(browse path: String, completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        return request(browse: path, with: [:], completion: handler)
    }
    
    func request(browse path: String, with headers: [String: String], completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        guard let url = URL(string: "\(endpoint)\(path)") else {
            Log.error("Unable to parse URL with endpoint \"%@\" at path \"%@\"", endpoint, path)
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        return request(browse: url, headers: headers, completion: handler)
    }
    
    func request(ajax path: String, completion handler: @escaping NineAnimatorCallback<NSDictionary>) -> NineAnimatorAsyncTask? {
        return request(ajax: path, with: [:], completion: handler)
    }
    
    func request(ajax path: String, with headers: [String: String], completion handler: @escaping NineAnimatorCallback<NSDictionary>) -> NineAnimatorAsyncTask? {
        guard let url = URL(string: "\(endpoint)\(path)") else {
            Log.error("Unable to parse URL with endpoint \"%@\" at path \"%@\"", endpoint, path)
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        return request(ajax: url, headers: headers, completion: handler)
    }
    
    func request(ajaxString path: String, completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        return request(ajaxString: path, with: [:], completion: handler)
    }
    
    func request(ajaxString path: String, with headers: [String: String], completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        guard let url = URL(string: "\(endpoint)\(path)") else {
            Log.error("Unable to parse URL with endpoint \"%@\" at path \"%@\"", endpoint, path)
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        return request(ajaxString: url, headers: headers, completion: handler)
    }
}
