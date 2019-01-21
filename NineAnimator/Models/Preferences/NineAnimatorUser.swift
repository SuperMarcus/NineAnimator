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

/**
 A concentral place for user data.
 
 This class is used to manage all the user datas such as playback
 progresses, search history, and viewing history. In a nutshell,
 it's a wrapper for UserDefaults, and may be used to integrate
 with other websites like MAL.
 
 Right now this class is basically an event handler for
 AnimeViewController and a data source for
 RecentlyViewedTableViewController
 */
class NineAnimatorUser {
    private let _freezer = UserDefaults.standard
    
    private var _syncingServices = [SyncingService]()
    
    private var _dirtyKeys = Set<PartialKeyPath<NineAnimatorUser>>()
    
    func clearAll() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        _freezer.removePersistentDomain(forName: bundleId)
    }
}

// MARK: - Playback Progresses & State Preservation
extension NineAnimatorUser {
    var lastEpisode: EpisodeLink? {
        return decode(EpisodeLink.self, from: _freezer.value(forKey: .recentEpisode))
    }
    
    var persistedProgresses: [String: Float] {
        get {
            if let dict = _freezer.dictionary(forKey: .persistedProgresses) as? [String: Float] { return dict } else { return [:] }
        }
        set { _freezer.set(newValue, forKey: .persistedProgresses) }
    }
    
    var recentAnimes: [AnimeLink] {
        get { return decode([AnimeLink].self, from: _freezer.value(forKey: .recentAnimeList)) ?? [] }
        set {
            guard let data = encode(data: newValue) else {
                return Log.error("Recent animes failed to encode")
            }
            _freezer.set(data, forKey: .recentAnimeList)
        }
    }
    
    var recentServer: Anime.ServerIdentifier? {
        get { return _freezer.string(forKey: .recentServer) }
        set { _freezer.set(newValue as String?, forKey: .recentServer) }
    }
    
    /// Triggered when an anime is presented
    ///
    /// - Parameter anime: AnimeLink of the anime
    func entering(anime: AnimeLink) {
        var animes = recentAnimes.filter { $0 != anime }
        animes.insert(anime, at: 0)
        recentAnimes = animes
    }
    
    /// Triggered when the playback is about to start
    ///
    /// - Parameter episode: EpisodeLink of the episode
    func entering(episode: EpisodeLink) {
        guard let data = encode(data: episode) else {
            Log.error("EpisodeLink failed to encode.")
            return
        }
        _freezer.set(data, forKey: .recentEpisode)
    }
    
    /// Periodically called by an observer in AVPlayer
    ///
    /// - Parameters:
    ///   - progress: Float value ranging from 0.0 to 1.0.
    ///   - episode: EpisodeLink of the episode.
    func update(progress: Float, for episode: EpisodeLink) {
        var store = persistedProgresses
        store["\(episode.parent.source.name)+\(episode.identifier)"] = progress
        persistedProgresses = store
        
        NotificationCenter.default.post(
            name: .playbackProgressDidUpdate,
            object: episode,
            userInfo: ["progress": progress]
        )
    }
    
    /// Retrive playback progress for episode
    ///
    /// - Parameter episode: EpisodeLink of the episode
    /// - Returns: Float value ranging from 0.0 to 1.0
    func playbackProgress(for episode: EpisodeLink) -> Float {
        return persistedProgresses["\(episode.parent.source.name)+\(episode.identifier)"] ?? 0
    }
    
    func clearRecents() {
        recentAnimes = []
        _freezer.removeObject(forKey: .recentEpisode)
    }
    
    /// Current anime source
    var source: Source {
        if let sourceName = _freezer.string(forKey: .recentSource),
            let source = NineAnimator.default.source(with: sourceName) {
            return source
        } else {
            return NineAnimator.default.sources.first!
        }
    }
    
    /// Select new anime source
    ///
    /// - Parameter source: New anime Source
    func select(source: Source) {
        _freezer.set(source.name, forKey: .recentSource)
        push()
    }
}

// MARK: - Preferences
extension NineAnimatorUser {
    enum EpisodeListingOrder: String {
        case ordered
        case reversed
        
        init(from value: Any?) {
            guard let value = value as? String else { self = .ordered; return }
            guard let order = EpisodeListingOrder(rawValue: value) else { self = .ordered; return }
            self = order
        }
    }
    
    var episodeListingOrder: EpisodeListingOrder {
        get { return EpisodeListingOrder(from: _freezer.string(forKey: .episodeListingOrder)) }
        set {
            _freezer.set(newValue.rawValue, forKey: .episodeListingOrder)
        }
    }
    
    var allowBackgroundPlayback: Bool {
        get { return _freezer.bool(forKey: .backgroundPlayback) }
        set {
            _freezer.set(newValue, forKey: .backgroundPlayback)
        }
    }
    
    var allowPictureInPicturePlayback: Bool {
        get { return _freezer.value(forKey: .pictureInPicturePlayback) as? Bool ?? true }
        set {
            _freezer.set(newValue, forKey: .pictureInPicturePlayback)
        }
    }
    
    var detectsPasteboardLinks: Bool {
        get { return _freezer.bool(forKey: .detectClipboardAnimeLinks) }
        set { _freezer.set(newValue, forKey: .detectClipboardAnimeLinks) }
    }
}

// MARK: - Cloud Sync
extension NineAnimatorUser {
    func register(syncingService: SyncingService) {
        _syncingServices.append(syncingService)
        syncingService.delegate = self
    }
    
    func pull() {
        
    }
    
    func push() {
        
    }
}

// MARK: - Watched anime stores
extension NineAnimatorUser {
    /**
     Returns the list of anime currently set to be notified for updates
     */
    var watchedAnimes: [AnimeLink] {
        get { return decode([AnimeLink].self, from: _freezer.value(forKey: .subscribedAnimeList)) ?? [] }
        set {
            guard let data = encode(data: newValue) else {
                return Log.error("Subscribed animes failed to encode")
            }
            _freezer.set(data, forKey: .subscribedAnimeList)
        }
    }
    
    /**
     Show what streaming services that the new episode of a subscribed anime
     is available on in an notification.
     */
    var notificationShowStreams: Bool {
        get { return _freezer.bool(forKey: .notificationShowStream) }
        set { _freezer.set(newValue, forKey: .notificationShowStream) }
    }
    
    /**
     Return if the provided link is being watched
     */
    func isWatching(anime: AnimeLink) -> Bool {
        return watchedAnimes.contains { $0 == anime }
    }
    
    /**
     An alias of isWatching(anime: AnimeLink)
     */
    func isWatching(_ anime: Anime) -> Bool { return isWatching(anime: anime.link) }
    
    /**
     Add the anime to the watch list
     */
    func watch(anime: Anime) {
        watch(uncached: anime.link)
        UserNotificationManager.default.update(anime)
    }
    
    /**
     Add AnimeLink to watch list but don't cache all the episodes just yet
     */
    func watch(uncached link: AnimeLink) {
        var newWatchList = watchedAnimes.filter { $0 != link }
        newWatchList.append(link)
        watchedAnimes = newWatchList
        UserNotificationManager.default.lazyPersist(link)
    }
    
    /**
     An alias of unwatch(anime: AnimeLink)
     */
    func unwatch(anime: Anime) { unwatch(anime: anime.link) }
    
    /**
     Remove the anime from the watch list
     */
    func unwatch(anime link: AnimeLink) {
        watchedAnimes = watchedAnimes.filter { $0 != link }
        UserNotificationManager.default.remove(link)
    }
    
    /**
     Remove all watched anime
     */
    func unwatchAll() {
        watchedAnimes.forEach(UserNotificationManager.default.remove)
        watchedAnimes = []
    }
}

// MARK: - Home Integration preferences
extension NineAnimatorUser {
    var homeIntegrationRunOnExternalPlaybackOnly: Bool {
        get {
            if let storedValue = _freezer.value(forKey: .homeExternalOnly) as? Bool {
                return storedValue
            }
            return true
        }
        set { _freezer.set(newValue, forKey: .homeExternalOnly) }
    }
    
    var homeIntegrationStartsActionSetUUID: UUID? {
        get {
            if let uuidString = _freezer.string(forKey: .homeUUIDStart) {
                return UUID(uuidString: uuidString)
            }
            return nil
        }
        set { _freezer.set(newValue?.uuidString, forKey: .homeUUIDStart) }
    }
    
    var homeIntegrationEndsActionSetUUID: UUID? {
        get {
            if let uuidString = _freezer.string(forKey: .homeUUIDEnd) {
                return UUID(uuidString: uuidString)
            }
            return nil
        }
        set { _freezer.set(newValue?.uuidString, forKey: .homeUUIDEnd) }
    }
}

// MARK: - Serialization helpers
private extension NineAnimatorUser {
    private func encode<T: Encodable>(data: T) -> Data? {
        let encoder = PropertyListEncoder()
        return try? encoder.encode(data)
    }
    
    private func decode<T: Decodable>(_ type: T.Type, from data: Any?) -> T? {
        guard let data = data as? Data else { return nil }
        let decoder = PropertyListDecoder()
        return try? decoder.decode(type, from: data)
    }
}

// MARK: - Private

fileprivate extension String {
    static var recentAnimeList: String { return "anime.recent" }
    static var detectClipboardAnimeLinks: String { return "anime.links.detect" }
    static var subscribedAnimeList: String { return "anime.subscribed" }
    static var recentEpisode: String { return "episode.recent" }
    static var recentSource: String { return "source.recent" }
    static var recentServer: String { return "server.recent" }
    static var persistedProgresses: String { return "episode.progress" }
    static var episodeListingOrder: String { return "episode.listing.order" }
    static var backgroundPlayback: String { return "playback.background" }
    static var pictureInPicturePlayback: String { return "playback.pip" }
    static var notificationShowStream: String { return "notification.showStreams" }
    static var homeExternalOnly: String { return "home.externalOnly" }
    static var homeUUIDStart: String { return "home.actionset.uuid.start" }
    static var homeUUIDEnd: String { return "home.actionset.uuid.end" }
    
    //Watching anime episodes persist filename
    static var watchedAnimesFileName: String { return "com.marcuszhou.NineAnimator.anime.watching.plist" }
}
