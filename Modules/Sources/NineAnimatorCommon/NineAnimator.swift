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

public class NineAnimator: Alamofire.SessionDelegate {
    public internal(set) static var `default` = NineAnimator()
    
    /// NineAnimator runtime properties
    public internal(set) static var runtime = NineAnimatorRuntime()
    
    /// Generate random application UUID
    public internal(set) static var applicationRuntimeUuid = UUID()
    
    /// Random runtime UUID bytes
    public class var applicationRuntimeUuidData: Data {
        withUnsafePointer(to: &applicationRuntimeUuid) {
            .init(bytes: $0, count: 16)
        }
    }
    
    /// A dummy artwork url
    public class var placeholderArtworkUrl: URL {
        NineAnimatorCloud.placeholderArtworkURL
    }
    
    /// Join NineAnimator community on Discord
    public class var discordServerInvitationUrl: URL {
        URL(string: "https://discord.gg/dzTVzeW")!
    }
    
    /// Specify how long the retrieved anime cache stays in the memory
    ///
    /// By default this is set to 30 minutes
    public class var animeCacheExpirationInterval: TimeInterval {
        60 * 30
    }
    
    /// Reachability manager
    public private(set) var reachability: NetworkReachabilityManager?
    
    /// NineAnimator Cloud services instance
    public private(set) var cloud = NineAnimatorCloud()
    
    private let mainAdditionalHeaders: HTTPHeaders = {
        var headers = HTTPHeaders.default
        headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.1 Safari/605.1.15"
        return headers
    }()
    
    public private(set) lazy var session: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpAdditionalHeaders = mainAdditionalHeaders.dictionary
        return Session(configuration: configuration, delegate: self)
    }()
    
    public private(set) lazy var ajaxSession: Session = {
        var ajaxAdditionalHeaders = mainAdditionalHeaders
        ajaxAdditionalHeaders["X-Requested-With"] = "XMLHttpRequest"
        ajaxAdditionalHeaders["Accept"] = "application/json, text/javascript, */*; q=0.01"
        
        let configuration = URLSessionConfiguration.af.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpAdditionalHeaders = ajaxAdditionalHeaders.dictionary
        return Session(configuration: configuration, delegate: self)
    }()
    
    /// User model
    public private(set) lazy var user = NineAnimatorUser()
    
    /// Container for the list of sources
    public private(set) var sources = [String: Source]()
    
    /// Container for the list of tracking services
    public private(set) var trackingServices = [ListingService]()
    
    /// A list of recommendation sources
    public private(set) var additionalRecommendationSources = [RecommendationSource]()
    
    /// Container for the cached references to tracking contexts
    fileprivate var trackingContextReferences = [AnimeLink: WeakRef<TrackingContext>]()
    
    /// An in-memory cache of all the loaded anime
    @AtomicProperty
    fileprivate var cachedAnimeMap = [AnimeLink: (Date, Anime)]()
    
    /// Global queue for modify internal configurations
    fileprivate static let globalConfigurationQueue = DispatchQueue(
        label: "com.marcuszhou.nineanimator.configuration",
        attributes: []
    )
    
    /// Chained image modifiers
    internal var _imageResourceModifiers = [Kingfisher.ImageDownloadRequestModifier]()
    
    internal init() {
        super.init(fileManager: .default)
        
        // Init reachability manager
        reachability = NetworkReachabilityManager()
        
        // Register Kingfisher request modifier
        setupGlobalImageRequestModifiers()
    }
}

public extension NineAnimator {
    func sortedRecommendationSources() -> [RecommendationSource] {
        let pool = additionalRecommendationSources
        // Later will add the featured containers
        return pool.sorted { $0.priority > $1.priority }
    }
    
    func register(additionalRecommendationSource source: RecommendationSource) {
        additionalRecommendationSources.append(source)
    }
}

// MARK: - Source management
public extension NineAnimator {
    /// Returns an array of enabled sources
    var enabledSources: [Source] {
        self.sources.values.filter(\.isEnabled)
    }
    
    /// Register a new source
    func register(source: Source) {
        let registeringSourceTypeName = String(describing: type(of: source))
        
        if let registeredSource = self.sources[source.name] {
            let existingSourceTypeName = String(describing: type(of: registeredSource))
            Log.fault("[NineAnimator] Cannot register anime source \"%@\" (%@) because another source (%@) has been registered with the same name. Remove the previous source before registering the new one.", source.name, registeringSourceTypeName, existingSourceTypeName)
        } else {
            self.sources[source.name] = source
            Log.info("[NineAnimator] Registered anime source \"%@\" (%@).", source.name, registeringSourceTypeName)
        }
    }
    
    /// Register a source by its type
    func register<SourceType: Source>(sourceType: SourceType.Type) {
        let source = SourceType(with: self)
        self.register(source: source)
    }
    
    /// Remove a source from the pool
    func remove(source: Source) {
        guard let removedSource = self.sources.removeValue(forKey: source.name) else {
            return Log.error("[NineAnimator] Failed to remove source with name \"%@\" because it was not registered.", source.name)
        }
        
        let removedSourceType = String(describing: type(of: removedSource))
        
        // Check if the one removed is the same instance as the parameter
        if ObjectIdentifier(removedSource) != ObjectIdentifier(source) {
            let parameterSourceType = String(describing: type(of: source))
            Log.fault("[NineAnimator] Removed a different instance of anime source \"%@\" (%@) than the one specified by the parameter (%@)!", removedSource.name, removedSourceType, parameterSourceType)
        } else {
            Log.info("[NineAnimator] Removed source \"%@\" (%@).", source.name, removedSourceType)
        }
    }
    
    /// Find the source with name
    func source(with name: String) -> Source? {
        if sources.isEmpty {
            Log.error("[NineAnimator] No source has been registered!! Has NineAnimator been properly initialized?")
            return nil
        }
        
        // Lookup by name directory, else search for aliases
        return sources[name] ?? sources.values.first {
            $0.aliases.contains(name)
        }
    }
}

// MARK: - Tracking & Listing services
public extension NineAnimator {
    /// Register a tracking service in NineAnimator
    func register(service: ListingService) {
        trackingServices.append(service)
        service.onRegister()
    }
    
    /// Register the list service by its implementation type
    func register<ListingServiceType: ListingService>(serviceType: ListingServiceType.Type) {
        let serviceInstance = ListingServiceType(self)
        return register(service: serviceInstance)
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
                _ = holdingReferenceContext // Just to silence the warning
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
public extension NineAnimator {
    func link(with url: URL, handler: @escaping NineAnimatorCallback<AnyLink>) -> NineAnimatorAsyncTask? {
        guard let parentSource = sources.values.first(where: { $0.canHandle(url: url) }) else {
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        
        return parentSource.link(from: url, handler)
    }
    
    func canHandle(link: URL) -> Bool {
        sources.values.contains { $0.canHandle(url: link) }
    }
}

// MARK: - Version information
public extension NineAnimator {
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
public extension NineAnimator {
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
                self.$cachedAnimeMap.mutate {
                    $0[link] = (Date(), result)
                }
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
