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
import SwiftSoup

/// Representing an retrieved anime
///
/// An Anime object represents a collection of information about the
/// AnimeLink, the streaming servers and episodes, as well as the
/// references to the tracking contexts of the AnimeLink.
public struct Anime {
    public typealias ServerIdentifier = String
    public typealias EpisodeIdentifier = String
    public typealias AnimeIdentifier = String
    public typealias EpisodeLinksCollection = [EpisodeLink]
    public typealias EpisodesCollection = [ServerIdentifier: EpisodeLinksCollection]
    public typealias AttributeKey = String
    
    public static let undeterminedServer: ServerIdentifier = "com.marcuszhou.nineanimator.anime.server._builtin.undetermined"
    
    public let link: AnimeLink
    public let servers: [ServerIdentifier: String]
    public let episodes: EpisodesCollection
    public let description: String
    public let alias: String
    public let episodesAttributes: [EpisodeLink: AdditionalEpisodeLinkInformation]
    
    /// The sub anime if this anime is the parent of a series of anime
    public let children: [Anime]
    
    /// The tracking context of the anime
    ///
    /// Reference to the tracking context is kept as long as
    /// a player is holding the PlaybackMedia (BasicPlaybackMedia)
    ///
    /// TrackingContext is not initialized during background fetch.
    public let trackingContext: TrackingContext
    
    public let additionalAttributes: [AttributeKey: Any]
    
    public var source: Source { link.source }
    
    public private(set) var currentServer: ServerIdentifier = undeterminedServer
    
    /// Initialize this Anime as a conventional anime
    public init(_ link: AnimeLink,
                alias: String = "",
                additionalAttributes: [AttributeKey: Any] = [:],
                description: String,
                on servers: [ServerIdentifier: String],
                episodes: [ServerIdentifier: EpisodeLinksCollection],
                episodesAttributes: [EpisodeLink: AdditionalEpisodeLinkInformation] = [:]) {
        self.link = link
        self.servers = servers
        self.episodes = episodes
        self.description = description
        self.alias = alias
        self.additionalAttributes = additionalAttributes
        self.episodesAttributes = episodesAttributes
        self.trackingContext = NineAnimator.default.trackingContext(for: link)
        self.children = []
        
        // Determine initial server selection
        self.determineInitialServer()
    }
    
    /// Initialize this Anime as the parent of a series
    public init(_ link: AnimeLink,
                alias: String = "",
                additionalAttributes: [AttributeKey: Any] = [:],
                description: String,
                children: [Anime]) {
        self.link = link
        self.alias = alias
        self.additionalAttributes = additionalAttributes
        self.description = description
        self.children = children
        self.episodesAttributes = [:]
        
        // Merge the available servers from the child anime object
        var knownServers = [ServerIdentifier: String]()
        for child in children {
            knownServers.merge(child.servers) { a, _ in a }
        }
        self.servers = knownServers
        
        // Merge episodes from children
        var episodes = EpisodesCollection()
        for child in children {
            for (server, collection) in child.episodes {
                let previousCollection = episodes[server] ?? []
                episodes[server] = previousCollection + collection
            }
        }
        self.episodes = episodes
        
        // Initialize the tracking context for the series
        // - May never be used
        self.trackingContext = NineAnimator.default.trackingContext(for: link)
        
        // Determine initial server selection
        self.determineInitialServer()
    }
    
    /// Retrieve the episode object
    public func episode(with link: EpisodeLink, onCompletion handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask? {
        source.episode(from: link, with: self, handler)
    }
    
    /// Retrieve all available links under the current server selection
    public var episodeLinks: EpisodeLinksCollection {
        episodes[currentServer] ?? []
    }
    
    /// Retrieve the number of episode links under the current server selection
    public var numberOfEpisodeLinks: Int {
        episodeLinks.count
    }
    
    /// Retrieve an episode link at index under the current server selection
    public func episodeLink(at index: Int) -> EpisodeLink {
        episodeLinks[index]
    }
    
    /// Find episodes on alternative different servers with the same name
    public func equivalentEpisodeLinks(of episodeLink: EpisodeLink) -> Set<EpisodeLink> {
        let results = episodes.filter {
            $0.key != episodeLink.server
        } .flatMap {
            $0.value.filter {
                $0.name == episodeLink.name && $0.parent == episodeLink.parent
            }
        }
        
        return Set(results + children.flatMap {
            $0.equivalentEpisodeLinks(of: episodeLink)
        })
    }
    
    /// Find episodes on the specified server with the same name
    public func equivalentEpisodeLinks(of episodeLink: EpisodeLink, onServer server: ServerIdentifier) -> EpisodeLink? {
        let result = episodes[server]?.first {
            $0.name == episodeLink.name && $0.parent == episodeLink.parent
        }
        
        if result == nil {
            return children.reduce(nil) {
                $0 ?? $1.equivalentEpisodeLinks(of: episodeLink, onServer: server)
            }
        } else { return result }
    }
    
    /// Change the selected server
    ///
    /// This operation may fail
    public mutating func select(server: ServerIdentifier) {
        if episodes[server] != nil {
            currentServer = server
            trackingContext.update(currentSessionServer: server)
        }
    }
    
    /// Prepare the anime for tracking services
    ///
    /// Invoking this method also prepares the children
    /// for tracking
    public func prepareForTracking() {
        // Prepare our tracking context
        trackingContext.prepareContext()
        // Prepare children's tracking contexts
        for child in children { child.prepareForTracking() }
    }
    
    /// Obtain the attributes for the episode link
    public func attributes(for episodeLink: EpisodeLink) -> AdditionalEpisodeLinkInformation? {
        // Search attribute in children first
        for child in children {
            if let attribute = child.attributes(for: episodeLink) {
                return attribute
            }
        }
        return episodesAttributes[episodeLink]
    }
    
    /// Determine the initial server selection for this anime
    ///
    /// Also See: Source.recommendServer(for:)
    private mutating func determineInitialServer() {
        // Previously selected server
        if let recentServer = NineAnimator.default.user.recentServer,
            servers[recentServer] != nil {
            return select(server: recentServer)
        }
        
        // If the previous server is not available, then prioritize
        // the server used previously by the user for this anime
        if let previousServer = trackingContext.previousSessionServer,
            servers[previousServer] != nil {
            return select(server: previousServer)
        }
        
        // If there is no previous record of server selection or
        // that the record had become invalid, use Source recommended
        // server
        if let sourceRecommendedServer = source.recommendServer(for: self) {
            return select(server: sourceRecommendedServer)
        }
        
        // If even the source cannot recommend a server, fallback to
        // the default behavior -- use the first available server
        select(server: servers.first?.key ?? Anime.undeterminedServer)
    }
}

public extension Anime {
    /// A set of optional information to the EpisodeLink.
    ///
    /// Attached to the Anime object to provide additional
    /// information for EpisodeLink struct
    struct AdditionalEpisodeLinkInformation {
        public var parent: EpisodeLink
        public var synopsis: String?
        public var airDate: String?
        public var season: String?
        public var episodeNumber: Int?
        public var title: String?
        
        public init(parent: EpisodeLink,
                    synopsis: String? = nil,
                    airDate: String? = nil,
                    season: String? = nil,
                    episodeNumber: Int? = nil,
                    title: String? = nil) {
            self.parent = parent
            self.synopsis = synopsis
            self.airDate = airDate
            self.season = season
            self.episodeNumber = episodeNumber
            self.title = title
        }
    }
}

public extension Anime.AttributeKey {
    static let rating: Anime.AttributeKey = "Ratings"
    
    static let ratingScale: Anime.AttributeKey = "Ratings Scale"
    
    static let airDate: Anime.AttributeKey = "Air Date"
}

public extension Dictionary where Key == Anime.ServerIdentifier, Value == Anime.EpisodeLinksCollection {
    var uniqueEpisodeNames: [String] {
        var names = [String]()
        self.flatMap { $0.value }.forEach {
            episodeLink in
            if !names.contains(where: { $0 == episodeLink.name }) {
                names.append(episodeLink.name)
            }
        }
        return names
    }
    
    func links(withName episodeName: String) -> [EpisodeLink] {
        self.flatMap { $0.value }
            .filter { $0.name == episodeName }
    }
    
    func link(withIdentifier episodeIdentifier: String) -> EpisodeLink? {
        self.flatMap { $0.value }
            .first { $0.identifier == episodeIdentifier }
    }
}
