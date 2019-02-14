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

import Foundation

extension NineAnimatorUser {
    /// A list of AnimeLink ordered from recently viewed to distant
    ///
    /// Direct modification outside the scope of NineAnimatorUser should
    /// be prevented. Always use available methods when possible.
    var recentAnimes: [AnimeLink] {
        get { return decode([AnimeLink].self, from: _freezer.value(forKey: Keys.recentAnimeList)) ?? [] }
        set {
            guard let data = encode(data: newValue) else {
                return Log.error("Recent animes failed to encode")
            }
            _freezer.set(data, forKey: Keys.recentAnimeList)
        }
    }
    
    /// The currently selected source website
    var source: Source {
        if let sourceName = _freezer.string(forKey: Keys.recentSource),
            let source = NineAnimator.default.source(with: sourceName) {
            return source
        } else {
            return NineAnimator.default.sources.first!
        }
    }
    
    /// The `EpisodeLink` to the last viewed episode
    var lastEpisode: EpisodeLink? {
        return decode(EpisodeLink.self, from: _freezer.value(forKey: Keys.recentEpisode))
    }
    
    /// Recently accessed server identifier
    var recentServer: Anime.ServerIdentifier? {
        get { return _freezer.string(forKey: Keys.recentServer) }
        set { _freezer.set(newValue as String?, forKey: Keys.recentServer) }
    }
    
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
    func entering(anime: AnimeLink) {
        var animes = recentAnimes.filter { $0 != anime }
        animes.insert(anime, at: 0)
        recentAnimes = animes
    }
    
    /// Select a new source
    func select(source: Source) {
        _freezer.set(source.name, forKey: Keys.recentSource)
        push()
    }
    
    /// Triggered when the playback is about to start
    ///
    /// - Parameter episode: EpisodeLink of the episode
    func entering(episode: EpisodeLink) {
        guard let data = encode(data: episode) else {
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
