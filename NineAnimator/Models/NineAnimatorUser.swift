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
    private let _cloud = NSUbiquitousKeyValueStore.default
    
    private(set) var recentAnimes: [AnimeLink] {
        get { return decode([AnimeLink].self, from: _freezer.value(forKey: .recentAnimeList)) ?? [] }
        set {
            guard let data = encode(data: newValue) else {
                return debugPrint("Warn: Recent animes failed to encode")
            }
            _freezer.set(data, forKey: .recentAnimeList)
        }
    }
    
    var source: Source {
        if let sourceName = _freezer.string(forKey: .recentSource),
            let source = NineAnimator.default.source(with: sourceName) {
            return source
        } else {
            return NineAnimator.default.sources.first!
        }
    }
    
    var lastEpisode: EpisodeLink? {
        return decode(EpisodeLink.self, from: _freezer.value(forKey: .recentEpisode))
    }
    
    var persistedProgresses: [String: Float] {
        get {
            if let dict = _freezer.dictionary(forKey: .persistedProgresses) as? [String: Float]
            { return dict } else { return [:] }
        }
        set { _freezer.set(newValue, forKey: .persistedProgresses) }
    }
    
    /// Triggered when an anime is presented
    ///
    /// - Parameter anime: AnimeLink of the anime
    func entering(anime: AnimeLink) {
        var animes = recentAnimes.filter{ $0 != anime }
        animes.insert(anime, at: 0)
        recentAnimes = animes
    }
    
    func select(source: Source) {
        _freezer.set(source.name, forKey: .recentSource)
        push()
    }
    
    /// Triggered when the playback is about to start
    ///
    /// - Parameter episode: EpisodeLink of the episode
    func entering(episode: EpisodeLink) {
        guard let data = encode(data: episode) else {
            debugPrint("Warn: EpisodeLink failed to encode.")
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
    
    func clearAll() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        _freezer.removePersistentDomain(forName: bundleId)
    }
}

//MARK: - Preferences
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
        set { _freezer.set(newValue.rawValue, forKey: .episodeListingOrder) }
    }
}

//MARK: - Serialization
extension NineAnimatorUser {
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

//MARK: - Cloud Sync
extension NineAnimatorUser {
    enum MergePiority {
        case localFirst
        case remoteFirst
    }
    
    private var cloudRecentAnime: [AnimeLink] {
        get {
            return decode([AnimeLink].self, from: _cloud.data(forKey: .recentAnimeList)) ?? []
        }
        set {
            guard let data = encode(data: newValue) else {
                return debugPrint("Warn: Recent animes failed to encode")
            }
            _cloud.set(data, forKey: .recentAnimeList)
        }
    }
    
    private var cloudSource: Source {
        get {
            if let sourceName = _cloud.string(forKey: .recentSource),
                let source = NineAnimator.default.source(with: sourceName) {
                return source
            } else { return source }
        }
    }
    
    private var cloudLastEpisode: EpisodeLink? {
        get { return decode(EpisodeLink.self, from: _cloud) }
    }
    
    private var cloudPersistedProgresses: [String: Float] {
        get {
            if let dict = _cloud.dictionary(forKey: .persistedProgresses) as? [String: Float]
            { return dict } else { return [:] }
        }
        set { _cloud.set(newValue, forKey: .persistedProgresses) }
    }
    
    func pull(){
        //Not using iCloud rn
//        merge(piority: .remoteFirst)
    }
    
    func push(){
        //Not using iCloud rn
//        merge(piority: .localFirst)
    }
    
    func merge(piority: MergePiority){
//        debugPrint("Info: Synchronizing defaults with piority \(piority)")
        
        if piority == .remoteFirst { _cloud.synchronize() }
        
        //Merge recently watched anime
        let primaryRecentAnime = piority == .localFirst ?
            recentAnimes : cloudRecentAnime
        let secondaryRecentAnime = piority == .localFirst ?
            cloudRecentAnime : recentAnimes
        
        let mergedRecentAnime = merge(
            primary: primaryRecentAnime,
            secondary: secondaryRecentAnime)
        
        recentAnimes = mergedRecentAnime
        cloudRecentAnime = mergedRecentAnime
        
        //Merge source
        if piority == .localFirst { _cloud.set(source.name, forKey: .recentSource) }
        else { _freezer.set(_cloud.string(forKey: .recentSource) ?? source.name, forKey: .recentSource) }
        
        //Merge recent episode
        if piority == .localFirst {
            if let episode = _freezer.data(forKey: .recentEpisode) {
                _cloud.set(episode, forKey: .recentEpisode)
            }
        } else {
            if let episode = _cloud.data(forKey: .recentEpisode) {
                _freezer.set(episode, forKey: .recentEpisode)
            }
        }
        
        //Merge persisted progresses
        let primaryPersistedProgresses = piority == .localFirst ?
            persistedProgresses : cloudPersistedProgresses
        let secondaryPersistedProgresses = piority == .localFirst ?
            cloudPersistedProgresses : persistedProgresses
        
        let mergedPersistedProgresses = primaryPersistedProgresses.merging(secondaryPersistedProgresses)
            { v, _ in return v }
        cloudPersistedProgresses = mergedPersistedProgresses
        persistedProgresses = mergedPersistedProgresses
        
        _ = _cloud.synchronize()
        _ = _freezer.synchronize()
    }
    
    fileprivate func merge<T: Equatable>(primary: [T], secondary: [T]) -> [T] {
        return primary + secondary.filter({
            link in return !primary.contains { $0 == link }
        })
    }
}

fileprivate extension String {
    static var recentAnimeList: String { return "anime.recent" }
    static var recentEpisode: String { return "episode.recent" }
    static var recentSource: String { return "source.recent" }
    static var persistedProgresses: String { return "episode.progress" }
    static var episodeListingOrder: String { return "episode.listing.order" }
}
