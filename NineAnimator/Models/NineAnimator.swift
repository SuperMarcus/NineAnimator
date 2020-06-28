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
import Kingfisher

class NineAnimator: SessionDelegate {
    static var `default` = NineAnimator()
    
    /// NineAnimator runtime properties
    static var runtime = NineAnimatorRuntime()
    
    /// A dummy artwork url
    class var placeholderArtworkUrl: URL {
        URL(string: "https://nineanimator-api.marcuszhou.com/static/resources/artwork_not_available.jpg")!
    }
    
    /// Join NineAnimator community on Discord
    class var discordServerInvitationUrl: URL {
        URL(string: "https://discord.gg/dzTVzeW")!
    }
    
    /// Specify how long the retrieved anime cache stays in the memory
    ///
    /// By default this is set to 30 minutes
    class var animeCacheExpirationInterval: TimeInterval {
        60 * 30
    }
    
    /// Reachability manager
    private(set) var reachability: NetworkReachabilityManager?
    
    private let mainAdditionalHeaders: HTTPHeaders = {
        var headers = HTTPHeaders.default
        headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.1 Safari/605.1.15"
        return headers
    }()
    
    private(set) lazy var session: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpAdditionalHeaders = mainAdditionalHeaders.dictionary
        return Session(configuration: configuration, delegate: self)
    }()
    
    private(set) lazy var ajaxSession: Session = {
        var ajaxAdditionalHeaders = mainAdditionalHeaders
        ajaxAdditionalHeaders["X-Requested-With"] = "XMLHttpRequest"
        ajaxAdditionalHeaders["Accept"] = "application/json, text/javascript, */*; q=0.01"
        
        let configuration = URLSessionConfiguration.af.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpAdditionalHeaders = ajaxAdditionalHeaders.dictionary
        return Session(configuration: configuration, delegate: self)
    }()
    
    private(set) var user = NineAnimatorUser()
    
    /// Container for the list of sources
    private(set) var sources = [Source]()
    
    /// Container for the list of tracking services
    private(set) var trackingServices = [ListingService]()
    
    /// A list of recommendation sources
    private(set) var additionalRecommendationSources = [RecommendationSource]()
    
    /// Container for the cached references to tracking contexts
    fileprivate var trackingContextReferences = [AnimeLink: WeakRef<TrackingContext>]()
    
    /// An in-memory cache of all the loaded anime
    fileprivate var cachedAnimeMap = [AnimeLink: (Date, Anime)]()
    
    /// Global queue for modify internal configurations
    fileprivate static let globalConfigurationQueue = DispatchQueue(
        label: "com.marcuszhou.nineanimator.configuration",
        attributes: []
    )
    
    /// Chained image modifiers
    var _imageResourceModifiers = [Kingfisher.ImageDownloadRequestModifier]()
    
    init() {
        super.init(fileManager: .default)
        
        // Init reachability manager
        reachability = NetworkReachabilityManager()
        
        // Register implemented sources and services
        registerDefaultSources()
        registerDefaultServices()
        setupGlobalImageRequestModifiers()
    }
}

extension NineAnimator {
    func sortedRecommendationSources() -> [RecommendationSource] {
        let pool = additionalRecommendationSources
        // Later will add the featured containers
        return pool.sorted { $0.piority > $1.piority }
    }
    
    func register(additionalRecommendationSource source: RecommendationSource) {
        additionalRecommendationSources.append(source)
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
        sources.first {
            $0.name == name || $0.aliases.contains(name)
        }
    }
    
    /// Register the default set of sources
    private func registerDefaultSources() {
        register(source: NASourceAnimePahe(with: self))
        register(source: NASourceFourAnime(with: self))
        register(source: NASourceGogoAnime(with: self))
        register(source: NASourceNineAnime(with: self))
        register(source: NASourceAnimeUltima(with: self))
        register(source: NASourceAnimeKisa(with: self))
        register(source: NASourceAnimeDao(with: self))
        register(source: NASourceAnimeTwist(with: self))
        register(source: NASourceKissanime(with: self))
        register(source: NASourceAnimeUnity(with: self))
        
        // Disabled sources
//        register(source: NASourceWonderfulSubs(with: self))
//        register(source: NASourceMasterAnime(with: self))
    }
}

// MARK: - Tracking & Listing services
extension NineAnimator {
    /// Register a tracking service in NineAnimator
    func register(service: ListingService) {
        trackingServices.append(service)
        service.onRegister()
    }
    
    /// Remove the service with name
    func remove(service: ListingService) {
        trackingServices.removeAll { $0.name == service.name }
    }
    
    /// Retrieve the service with name
    func service(with name: String) -> ListingService? {
        trackingServices.first { $0.name == name }
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
        // Remove dead contexts
        collectGarbage()
        // Return the context dirctly if it has been created
        if let context: TrackingContext = NineAnimator.globalConfigurationQueue.sync(execute: {
            trackingContextReferences[anime]?.object
        }) { return context }
        
        // If the context does not exists, create a new one
        let context = TrackingContext(self, link: anime)
        let ephemeralReference = WeakRef(context)
    
        // Store the reference in the pool for reuse
        NineAnimator.globalConfigurationQueue.async(flags: [ .barrier ]) {
            [ephemeralReference, context] in
            self.trackingContextReferences[anime] = ephemeralReference
            
            // Hold the reference for 10 seconds, then remove the strong reference
            // This improves the reusability of tracking contexts
            var holdingReferenceContext: TrackingContext? = context
            NineAnimator.globalConfigurationQueue.asyncAfter(deadline: .now() + 10) {
                holdingReferenceContext = nil
                _ = holdingReferenceContext // Just to silent the warning
            }
        }
        
        return context
    }
    
    /// Returning the list of TrackingContexts containing this reference
    func trackingContexts(containingReference reference: ListingAnimeReference) -> [TrackingContext] {
        var trackingContexts = [TrackingContext]()
        for recentAnime in user.recentAnimes {
            let context = trackingContext(for: recentAnime)
            if context.availableReferences.contains(reference) {
                trackingContexts.append(context)
            }
        }
        return trackingContexts
    }
    
    private func registerDefaultServices() {
        register(service: Anilist(self))
        register(service: Kitsu(self))
        register(service: MyAnimeList(self))
        register(service: Simkl(self))
    }
    
    /// Remove all expired weak references
    private func collectGarbage() {
        NineAnimator.globalConfigurationQueue.sync(flags: [ .barrier ]) {
            let before = self.trackingContextReferences.count
            self.trackingContextReferences = self.trackingContextReferences.filter {
                $0.value.object != nil
            }
            let diff = before - self.trackingContextReferences.count
            if diff > 0 { Log.error("[NineAnimator.TrackingContextPool] %@ references removed", diff) }
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
        sources.contains { $0.canHandle(url: link) }
    }
}

// MARK: - Version information
extension NineAnimator {
    /// The current verision string of NineAnimator
    var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "Unknown Version"
    }
    
    /// The current build number of NineAnimator
    var buildNumber: Int {
        guard let buildNumberString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
            let buildNumber = Int(buildNumberString) else { return -1 }
        return buildNumber
    }
}

// MARK: - Retrieving & Caching Anime
extension NineAnimator {
    /// Retrieve the `Anime` object for the `AnimeLink`
    /// - Note: This method uses the internal cache whenever possible.
    func anime(with link: AnimeLink, onCompletion handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask? {
        // If the anime has been cached and the cache is not expired
        let cachedVersion = cachedAnimeMap[link]
        if let (cachedDate, cachedAnime) = cachedVersion,
            (cachedDate.timeIntervalSinceNow + NineAnimator.animeCacheExpirationInterval) > 0 {
            Log.info(
                "[NineAnimator] Valid cache for anime \"%@\" was found and is selected. Cache for this anime will expire at %@.",
                link.title,
                cachedDate + NineAnimator.animeCacheExpirationInterval
            )
            handler(cachedAnime, nil)
            return nil
        }
        
        // Retrieve the anime with source
        return link.source.anime(from: link) {
            result, error in // Doesn't care about strong reference to self
            // If the result is not nil, cache the retrieved anime
            if let result = result {
                self.cachedAnimeMap[link] = (Date(), result)
                // Call the original handler
                handler(result, nil)
            } else if let cachedAnime = cachedVersion?.1 {
                Log.error(
                    "[NineAnimator] Unable to retrieve an up-to-date Anime object for \"%@\" (%@). A cached version will be returned.",
                    link.title,
                    error.debugDescription
                )
                // Call the handler with the cached version
                handler(cachedAnime, nil)
            } else {
                Log.error(
                    "[NineAnimator] Unable to retrieve the Anime object for \"%@\" (%@).",
                    link.title,
                    error.debugDescription
                )
                // Call the original handler
                handler(result, error)
            }
        }
    }
    
    /// Return a promise that would retrieve the `Anime` object for the `AnimeLink`
    func anime(with link: AnimeLink) -> NineAnimatorPromise<Anime> {
        .init { self.anime(with: link, onCompletion: $0) }
    }
}
