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

import Foundation

extension NineAnimatorUser {
    /// A list of persisted progresses
    var persistedProgresses: [String: Float] {
        get {
            if let dict = _freezer.dictionary(forKey: Keys.persistedProgresses) as? [String: Float] { return dict } else { return [:] }
        }
        set { _freezer.set(newValue, forKey: Keys.persistedProgresses) }
    }
    
    /// Triggered when an anime is presented
    ///
    /// - Parameter anime: AnimeLink of the anime
    /// - Important: Only call this method on the main thread
    func entering(anime: AnimeLink) {
        do {
            try coreDataLibrary.mainContext.updateLibraryRecord(forLink: .anime(anime))
        } catch {
            Log.error("[NineAnimatorUser] Unable to record recently viewed item because of error: %@", error)
        }
    }
    
    /// Triggered when the playback is about to start
    ///
    /// - Parameter episode: EpisodeLink of the episode
    /// - Important: Only call this method on the main thread
    func entering(episode: EpisodeLink) {
        guard let data = encodeIfPresent(data: episode) else {
            Log.error("EpisodeLink failed to encode.")
            return
        }
        _freezer.set(data, forKey: Keys.recentEpisode)
    }
    
    /// Periodically called by an observer in AVPlayer
    ///
    /// - Parameters:
    ///   - progress: Float value ranging from 0.0 to 1.0.
    ///   - episode: EpisodeLink of the episode.
    func update(progress: Float, for episode: EpisodeLink) {
        let clippedProgress = max(min(1.0, progress), 0.0)
        var store = persistedProgresses
        store["\(episode.parent.source.name)+\(episode.identifier)"] = clippedProgress
        persistedProgresses = store
        
        NotificationCenter.default.post(
            name: .playbackProgressDidUpdate,
            object: episode,
            userInfo: ["progress": clippedProgress]
        )
    }
    
    /// Retrive playback progress for episode
    ///
    /// - Parameter episode: EpisodeLink of the episode
    /// - Returns: Float value ranging from 0.0 to 1.0
    func playbackProgress(for episode: EpisodeLink) -> Float {
        let persistedProgress = persistedProgresses["\(episode.parent.source.name)+\(episode.identifier)"] ?? 0
        return max(min(persistedProgress, 1.0), 0.0)
    }
}

// MARK: - Search History
extension NineAnimatorUser {
    /// The user's search history listed from the most recent to distant
    private(set) var searchHistory: [String] {
        get { _freezer.typedValue(forKey: Keys.searchHistory, default: []) }
        set { _freezer.set(newValue, forKey: Keys.searchHistory) }
    }
    
    /// Enqueue a search history item
    func enqueueSearchHistory(_ keywords: String) {
        var mutatingHistory = searchHistory
        
        mutatingHistory.removeAll {
            $0.caseInsensitiveCompare(keywords) == .orderedSame
        }
        mutatingHistory.insert(keywords, at: 0)
        
        if mutatingHistory.count > 10 {
            mutatingHistory = Array(mutatingHistory[0...9])
        }
        
        searchHistory = mutatingHistory
    }
    
    /// Clear the search history
    func clearSearchHistory() {
        _freezer.removeObject(forKey: Keys.searchHistory)
    }
}

// MARK: - Recents
extension NineAnimatorUser {
    /// A list of AnimeLink ordered from recently viewed to distant
    ///
    /// Direct modification outside the scope of NineAnimatorUser should
    /// be prevented. Always use available methods when possible.
    var recentAnimes: [AnimeLink] {
        get {
            do {
                return try coreDataLibrary.mainContext.fetchRecents().compactMap {
                    anyLink in
                    if case let .anime(animeLink) = anyLink {
                        return animeLink
                    } else { return nil }
                }
            } catch {
                Log.error("[NineAnimatorUser] Unable to decode recent list: %@", error)
                return []
            }
        }
        set {
            do {
                try coreDataLibrary.mainContext.resetRecents(to: newValue.map {
                    .anime($0)
                })
            } catch {
                Log.error("[NineAnimatorUser] Unable to save recent list: %@", error)
            }
        }
//        get { decodeIfPresent([AnimeLink].self, from: _freezer.value(forKey: Keys.recentAnimeList)) ?? [] }
//        set {
//            guard let data = encodeIfPresent(data: newValue) else {
//                return Log.error("Recent animes failed to encode")
//            }
//            _freezer.set(data, forKey: Keys.recentAnimeList)
//        }
    }
    
    /// The `EpisodeLink` to the last viewed episode
    var lastEpisode: EpisodeLink? {
        decodeIfPresent(EpisodeLink.self, from: _freezer.value(forKey: Keys.recentEpisode))
    }
    
    /// Recently accessed server identifier
    var recentServer: Anime.ServerIdentifier? {
        get { _freezer.string(forKey: Keys.recentServer) }
        set { _freezer.set(newValue as String?, forKey: Keys.recentServer) }
    }
    
    /// Remove all anime viewing history
    func clearRecents() {
        _freezer.removeObject(forKey: Keys.recentEpisode)
        _freezer.removeObject(forKey: Keys.recentAnimeList)
        _freezer.removeObject(forKey: Keys.recentServer)
    }
}

// MARK: - Source
extension NineAnimatorUser {
    /// The currently selected source website
    var source: Source {
        if let sourceName = _freezer.string(forKey: Keys.recentSource),
            let source = NineAnimator.default.source(with: sourceName),
            source.isEnabled {
            return source
        } else {
            // Return the first available source
            return NineAnimator.default.sources.first { $0.isEnabled }!
        }
    }
    
    /// Select a new source
    func select(source: Source) {
        _freezer.set(source.name, forKey: Keys.recentSource)
        push()
    }
}
