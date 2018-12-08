//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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

import Foundation
import Alamofire

typealias NineAnimatorCallback<T> = (T?, Error?) -> ()

enum NineAnimatorError: Error {
    case urlError
    case responseError(String)
    case providerError(String)
    case noResults
}

protocol NineAnimatorAsyncTask {
    func cancel()
}

extension Alamofire.DataRequest: NineAnimatorAsyncTask { }

class NineAnimator: Alamofire.SessionDelegate {
    static var `default` = NineAnimator()
    
    let endpoint = "https://www1.9anime.to"
    
    let client = URLSession(configuration: .default)
    
    var session: Alamofire.SessionManager!
    
    var ajaxSession: Alamofire.SessionManager!
    
    var cache = [NineAnimatePath:String]()
    
    override init() {
        super.init()
        
        var mainAdditionalHeaders = Alamofire.SessionManager.defaultHTTPHeaders
        mainAdditionalHeaders["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.1 Safari/605.1.15"
        mainAdditionalHeaders["Accept-Language"] = "en-us"
        
        var ajaxAdditionalHeaders = mainAdditionalHeaders
        ajaxAdditionalHeaders["X-Requested-With"] = "XMLHttpRequest"
        ajaxAdditionalHeaders["Accept"] = "application/json, text/javascript, */*; q=0.01"
        
        let mainSessionConfiguration = URLSessionConfiguration.default
        mainSessionConfiguration.httpShouldSetCookies = true
        mainSessionConfiguration.httpCookieAcceptPolicy = .always
        mainSessionConfiguration.httpAdditionalHeaders = mainAdditionalHeaders
        session = Alamofire.SessionManager(configuration: mainSessionConfiguration, delegate: self)
        
        let ajaxSessionConfiguration = URLSessionConfiguration.default
        ajaxSessionConfiguration.httpShouldSetCookies = true
        ajaxSessionConfiguration.httpCookieAcceptPolicy = .always
        ajaxSessionConfiguration.httpAdditionalHeaders = ajaxAdditionalHeaders
        ajaxSession = Alamofire.SessionManager(configuration: ajaxSessionConfiguration, delegate: self)
    }
    
    func removeCache(at path: NineAnimatePath){
        cache.removeValue(forKey: path)
    }
    
    func request(_ path: NineAnimatePath, forceReload: Bool = false, onCompletion: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        if !forceReload, let cachedData = cache[path] {
            onCompletion(cachedData, nil)
        }
        
        guard let url = URL(string: endpoint + path.value) else {
            onCompletion(nil, NineAnimatorError.urlError)
            return nil
        }
        
        return session.request(url).responseString {
            response in
            if case let .failure(error) = response.result {
                debugPrint("Error: Failiure on request: \(error)")
                onCompletion(nil, error)
                return
            }
            
            guard let value = response.value else {
                debugPrint("Error: No data received")
                onCompletion(nil, NineAnimatorError.responseError("no data received"))
                return
            }
            
            //Cache value
            self.cache[path] = value
            onCompletion(value, nil)
        }
    }
}
