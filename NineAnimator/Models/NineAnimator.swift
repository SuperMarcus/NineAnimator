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

extension DataRequest: NineAnimatorAsyncTask { }

class NineAnimator: SessionDelegate {
    static var `default` = NineAnimator()
    
    let client = URLSession(configuration: .default)
    
    private let mainAdditionalHeaders: HTTPHeaders = {
        var headers = SessionManager.defaultHTTPHeaders
        headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.1 Safari/605.1.15"
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
    
    private(set) var user = NineAnimatorUser()
    
    /// Container for the list of sources
    private(set) var sources = [Source]()
    
    /// Container for the list of tracking services
    private(set) var trackingServices = [ListingService]()
    
    /// Container for the cached references to tracking contexts
    fileprivate var trackingContextReferences = [AnimeLink: WeakRef<TrackingContext>]()
    
    /// Queue for modify internal configurations
    private let configurationQueue: DispatchQueue = .global()
    
    override init() {
        super.init()
        
        // Register implemented sources and services
        registerDefaultSources()
        registerDefaultServices()
    }
}

// MARK: - Source management
extension NineAnimator {
    /// Register a new source
    func register(source: Source) { sources.append(source) }
    
    /// Remove a source from the pool
    func remove(source: Source) {
        sources.removeAll { $0.name == source.name }
    }
    
    /// Find the source with name
    func source(with name: String) -> Source? {
        return sources.first { $0.name == name }
    }
    
    /// Register the default set of sources
    private func registerDefaultSources() {
        register(source: NASourceNineAnime(with: self))
        register(source: NASourceMasterAnime(with: self))
        register(source: NASourceGogoAnime(with: self))
        register(source: NASourceAnimeTwist(with: self))
        register(source: NASourceWonderfulSubs(with: self))
//        register(source: NASourceAnimeUltima(with: self))
    }
}

// MARK: - Tracking & Listing services
extension NineAnimator {
    /// Register a tracking service in NineAnimator
    func register(service: ListingService) { trackingServices.append(service) }
    
    /// Remove the service with name
    func remove(service: ListingService) {
        trackingServices.removeAll { $0.name == service.name }
    }
    
    /// Retrieve the service with name
    func service(with name: String) -> ListingService? {
        return trackingServices.first { $0.name == name }
    }
    
    /// Retrieve the service with the specific type
    func service<T: ListingService>(type: T.Type) -> T {
        if let service = trackingServices.first(where: { $0 is T }) as? T {
            return service
        } else {
            let newService = T(self)
            register(service: newService)
            return newService
        }
    }
    
    /// Retrieve the tracking context for the anime
    func trackingContext(for anime: AnimeLink) -> TrackingContext {
        return configurationQueue.sync {
            // If the context has been created, use the cached one
            if let context = trackingContextReferences[anime]?.object {
                return context
            }
            
            // If the context does not exists, create a new one
            let context = TrackingContext(self, link: anime)
            let ephemeralReference = WeakRef(context)
            trackingContextReferences[anime] = ephemeralReference
            return context
        }
    }
    
    private func registerDefaultServices() {
        register(service: Anilist(self))
        register(service: Kitsu(self))
        register(service: MyAnimeList(self))
    }
    
    /// Remove all expired weak references
    private func collectGarbage() {
        for (index, ref) in self.trackingContextReferences where ref.object == nil {
            self.trackingContextReferences.removeValue(forKey: index)
        }
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
