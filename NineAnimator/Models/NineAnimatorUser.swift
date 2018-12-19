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
    
    private(set) var recentAnimes: [AnimeLink] {
        get {
            let decoder = PropertyListDecoder()
            if let data = _freezer.value(forKey: "anime.recent") as? Data,
                let recents = try? decoder.decode([AnimeLink].self, from: data) {
                return recents
            }
            return []
        }
        set {
            let encoder = PropertyListEncoder()
            guard let data = try? encoder.encode(newValue) else {
                return debugPrint("Warn: Recent animes failed to encode")
            }
            _freezer.set(data, forKey: "anime.recent")
        }
    }
    
    var source: Source {
        if let sourceName = _freezer.string(forKey: "source.recent"),
            let source = NineAnimator.default.source(with: sourceName) {
            return source
        } else {
            return NineAnimator.default.sources.first!
        }
    }
    
    var lastEpisode: EpisodeLink? {
        let decoder = PropertyListDecoder()
        if let data = _freezer.value(forKey: "episode.recent") as? Data {
            return try? decoder.decode(EpisodeLink.self, from: data)
        }
        return nil
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
        _freezer.set(source.name, forKey: "source.recent")
    }
    
    /// Triggered when the playback is about to start
    ///
    /// - Parameter episode: EpisodeLink of the episode
    func entering(episode: EpisodeLink) {
        let encoder = PropertyListEncoder()
        guard let data = try? encoder.encode(episode) else {
            debugPrint("Warn: EpisodeLink failed to encode.")
            return
        }
        _freezer.set(data, forKey: "episode.recent")
    }
    
    /// Periodically called by an observer in AVPlayer
    ///
    /// - Parameters:
    ///   - progress: Float value ranging from 0.0 to 1.0.
    ///   - episode: EpisodeLink of the episode.
    func update(progress: Float, for episode: EpisodeLink) {
        let key = "\(episode).progress"
        _freezer.set(progress, forKey: key)
    }
    
    /// Retrive playback progress for episode
    ///
    /// - Parameter episode: EpisodeLink of the episode
    /// - Returns: Float value ranging from 0.0 to 1.0
    func playbackProgress(for episode: EpisodeLink) -> Float {
        let key = "\(episode).progress"
        return _freezer.float(forKey: key)
    }
    
    func clear() {
        recentAnimes = []
        _freezer.removeObject(forKey: "episode.recent")
    }
}
