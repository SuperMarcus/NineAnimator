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

import Alamofire
import Foundation

typealias NineAnimatorCallback<T> = (T?, Error?) -> Void

enum NineAnimatorError: Error {
    case urlError
    case responseError(String)
    case providerError(String)
    case noResults
    case decodeError
}

protocol NineAnimatorAsyncTask {
    func cancel()
}

/// This class is used to keep track of multiple async tasks that might be needed
class NineAnimatorMultistepAsyncTask: NineAnimatorAsyncTask {
    var tasks: [NineAnimatorAsyncTask]
    
    init() { tasks = [] }
    
    func add(_ task: NineAnimatorAsyncTask?) { if let task = task { tasks.append(task) } }
    
    func cancel() { for task in tasks { task.cancel() } }
    
    deinit { cancel(); tasks = [] }
}

extension DataRequest: NineAnimatorAsyncTask { }

class NineAnimator: SessionDelegate {
    static var `default` = NineAnimator()
    
    let client = URLSession(configuration: .default)
    
    var session: SessionManager!
    
    var ajaxSession: SessionManager!
    
    var user = NineAnimatorUser()
    
    var sources = [Source]()
    
    override init() {
        super.init()
        
        var mainAdditionalHeaders = SessionManager.defaultHTTPHeaders
        mainAdditionalHeaders["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.1 Safari/605.1.15"
        mainAdditionalHeaders["Accept-Language"] = "en-us"
        
        var ajaxAdditionalHeaders = mainAdditionalHeaders
        ajaxAdditionalHeaders["X-Requested-With"] = "XMLHttpRequest"
        ajaxAdditionalHeaders["Accept"] = "application/json, text/javascript, */*; q=0.01"
        
        let mainSessionConfiguration = URLSessionConfiguration.default
        mainSessionConfiguration.httpShouldSetCookies = true
        mainSessionConfiguration.httpCookieAcceptPolicy = .always
        mainSessionConfiguration.httpAdditionalHeaders = mainAdditionalHeaders
        session = SessionManager(configuration: mainSessionConfiguration, delegate: self)
        
        let ajaxSessionConfiguration = URLSessionConfiguration.default
        ajaxSessionConfiguration.httpShouldSetCookies = true
        ajaxSessionConfiguration.httpCookieAcceptPolicy = .always
        ajaxSessionConfiguration.httpAdditionalHeaders = ajaxAdditionalHeaders
        ajaxSession = SessionManager(configuration: ajaxSessionConfiguration, delegate: self)
        
        registerDefaultSources()
    }
    
    func register(source: Source) { sources.append(source) }
    
    func remove(source: Source) {
        sources.removeAll { $0.name == source.name }
    }
    
    func source(with name: String) -> Source? {
        return sources.first { $0.name == name }
    }
    
    private func registerDefaultSources() {
        register(source: NineAnimeSource(with: self))
        register(source: NASourceMasterAnime(with: self))
    }
}
