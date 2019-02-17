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
import SwiftSoup

extension NineAnimator {
    func anime(with link: AnimeLink, onCompletion handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask? {
        return link.source.anime(from: link, handler)
    }
}

struct Anime {
    typealias ServerIdentifier = String
    typealias EpisodeIdentifier = String
    typealias AnimeIdentifier = String
    typealias EpisodeLinksCollection = [EpisodeLink]
    typealias EpisodesCollection = [ServerIdentifier: EpisodeLinksCollection]
    typealias AttributeKey = String
    
    let link: AnimeLink
    let servers: [ServerIdentifier: String]
    let episodes: EpisodesCollection
    let description: String
    let alias: String
    let episodesAttributes: [EpisodeLink: AdditionalEpisodeLinkInformation]
    
    /// The tracking context of the anime
    ///
    /// Reference to the tracking context is kept as long as
    /// a player is holding the PlaybackMedia (BasicPlaybackMedia)
    let trackingContext: TrackingContext
    
    let additionalAttributes: [AttributeKey: Any]
    
    var currentServer: ServerIdentifier
    
    var source: Source { return link.source }
    
    init(_ link: AnimeLink,
         alias: String = "",
         additionalAttributes: [AttributeKey: Any] = [:],
         description: String,
         on servers: [ServerIdentifier: String],
         episodes: [ServerIdentifier: EpisodeLinksCollection],
         episodesAttributes: [EpisodeLink: AdditionalEpisodeLinkInformation] = [:]) {
        self.link = link
        self.servers = servers
        self.episodes = episodes
        self.currentServer = servers.first!.key
        self.description = description
        self.alias = alias
        self.additionalAttributes = additionalAttributes
        self.episodesAttributes = episodesAttributes
        self.trackingContext = NineAnimator.default.trackingContext(for: link)
    }
    
    func episode(with link: EpisodeLink, onCompletion handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask? {
        return source.episode(from: link, with: self, handler)
    }
}

extension Anime {
    /// A set of optional information to the EpisodeLink.
    ///
    /// Attached to the Anime object to provide additional
    /// information for EpisodeLink struct
    struct AdditionalEpisodeLinkInformation {
        var parent: EpisodeLink
        
        var synopsis: String?
        
        var airDate: String?
        
        var episodeNumber: Int?
        
        var title: String?
    }
}

extension Anime.AttributeKey {
    static let rating: Anime.AttributeKey = "Ratings"
    
    static let ratingScale: Anime.AttributeKey = "Ratings Scale"
    
    static let airDate: Anime.AttributeKey = "Air Date"
}

extension Dictionary where Key == Anime.ServerIdentifier, Value == Anime.EpisodeLinksCollection {
    var uniqueEpisodeNames: [String] {
        var names = [String]()
        self.flatMap { $0.value }.forEach {
            episodeLink in
            if !names.contains { $0 == episodeLink.name } {
                names.append(episodeLink.name)
            }
        }
        return names
    }
    
    func links(withName episodeName: String) -> [EpisodeLink] {
        return self.flatMap { $0.value }
            .filter { $0.name == episodeName }
    }
    
    func link(withIdentifier episodeIdentifier: String) -> EpisodeLink? {
        return self.flatMap { $0.value }
            .first { $0.identifier == episodeIdentifier }
    }
}
