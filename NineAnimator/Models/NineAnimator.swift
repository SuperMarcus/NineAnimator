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

typealias NineAnimatorCallback<T> = (T?, Error?) -> Void

enum NineAnimatorError: Error, CustomStringConvertible {
    case urlError
    case responseError(String)
    case providerError(String)
    case searchError(String)
    case authenticationRequiredError(String, URL?)
    case decodeError
    case unknownError
    case lastItemInQueueError
    
    var description: String {
        switch self {
        case .decodeError: return  "Cannot decode an encoded media. This app might be outdated."
        case .urlError: return "There is something wrong with the URL"
        case .responseError(let errorString): return "Response Error: \(errorString)"
        case .providerError(let errorString): return "Provider Error: \(errorString)"
        case .searchError(let errorString): return "Search Error: \(errorString)"
        case .lastItemInQueueError: return "The selected item is the last item in the queue."
        case let .authenticationRequiredError(message, url):
            let urlDescription = url == nil ? "" : " (\(url!))"
            return "Authentication required: \(message)\(urlDescription)"
        case .unknownError: return "Unknwon Error"
        }
    }
}

extension DataRequest: NineAnimatorAsyncTask { }

class NineAnimator: SessionDelegate {
    static var `default` = NineAnimator()
    
    let client = URLSession(configuration: .default)
    
    private let mainAdditionalHeaders: HTTPHeaders = {
        var headers = SessionManager.defaultHTTPHeaders
        headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.1 Safari/605.1.15"
        headers["Accept-Language"] = "en-us"
        return headers
    }()
    
    private(set) lazy var session: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpAdditionalHeaders = mainAdditionalHeaders
        return SessionManager(configuration: configuration, delegate: self)
    }()
    
    private(set) lazy var ajaxSession: SessionManager = {
        var ajaxAdditionalHeaders = mainAdditionalHeaders
        ajaxAdditionalHeaders["X-Requested-With"] = "XMLHttpRequest"
        ajaxAdditionalHeaders["Accept"] = "application/json, text/javascript, */*; q=0.01"
        
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpAdditionalHeaders = ajaxAdditionalHeaders
        return SessionManager(configuration: configuration, delegate: self)
    }()
    
    var user = NineAnimatorUser()
    
    var sources = [Source]()
    
    override init() {
        super.init()
        registerDefaultSources()
    }
}

// MARK: - Source management
extension NineAnimator {
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
        register(source: NASourceGogoAnime(with: self))
    }
}

// MARK: - Retriving and identifying links
extension NineAnimator {
    func link(with url: URL, handler: @escaping NineAnimatorCallback<AnyLink>) -> NineAnimatorAsyncTask? {
        guard let parentSource = sources.first(where: { $0.canHandle(url: url) }) else {
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        
        return parentSource.link(from: url, handler)
    }
    
    func canHandle(link: URL) -> Bool {
        return sources.reduce(false) { $0 || $1.canHandle(url: link) }
    }
}
