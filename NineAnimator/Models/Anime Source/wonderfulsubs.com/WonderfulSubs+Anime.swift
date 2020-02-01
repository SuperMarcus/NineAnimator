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

extension NASourceWonderfulSubs {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        request(
            ajaxPathDictionary: "/api/media/series",
            query: [ "series": link.link.lastPathComponent ],
            headers: [ "Referer": link.link.absoluteString ]
        ) .then {
            response in
            let detailedSeriesEntry = try response.value(at: "json", type: NSDictionary.self)
            let reassembledLink = try self.constructAnimeLink(from: detailedSeriesEntry, withParent: link)
            let aliases = detailedSeriesEntry.valueIfPresent(at: "aliases", type: [String].self) ?? []
            let description = try detailedSeriesEntry.value(at: "description", type: String.self)
            
            // Construct child anime
            let seasons = try detailedSeriesEntry.value(at: "seasons", type: NSDictionary.self)
            let medias = try seasons
                .compactMap { _, season in season as? NSDictionary }
                .flatMap { try $0.value(at: "media", type: [NSDictionary].self) }
            let children = medias.compactMap { try? self.anime(fromMediaEntry: $0, withParent: reassembledLink) }
            
            // Handle empty children list
            guard !children.isEmpty else {
                throw NineAnimatorError.responseError("No seasons found for this anime")
            }
            
            // Construct the parent Anime object
            return Anime(
                reassembledLink,
                alias: aliases.joined(separator: "; "),
                description: description,
                children: children
            )
        }
    }
    
    /// For WonderfulSubs, this is a rather tedius and computational intensive task
    private func anime(fromMediaEntry mediaEntry: NSDictionary, withParent parent: AnimeLink) throws -> Anime {
        guard var urlBuilder = URLComponents(url: parent.link, resolvingAgainstBaseURL: false) else {
            throw NineAnimatorError.urlError
        }
        
        let title = mediaEntry.valueIfPresent(at: "title", type: String.self) ?? parent.title
        let alias: String
        let description = "No synopsis found for this season"
        
        // Use the Japanese title as alias if it is present
        if let japaneseTitle = mediaEntry["japanese_title"] as? String {
            alias = japaneseTitle
        } else { alias = "" }
        
        // Construct a seperate AnimeLink for this season
        urlBuilder.fragment = title
        let animeLink = AnimeLink(
            title: title,
            link: try some(urlBuilder.url, or: .urlError),
            image: parent.image,
            source: self
        )
        
        // First, retrieve the list of episodes from the episodes entry
        let retrievedEpisodes = try mediaEntry
            .value(at: "episodes", type: [NSDictionary].self)
            .flatMap {
                episodeEntry -> ([(EpisodeLink, Anime.AdditionalEpisodeLinkInformation)]) in
                // Basic information
                let episodeNumber: Double
                if let number = episodeEntry.valueIfPresent(at: "episode_number", type: Int.self) {
                    episodeNumber = Double(number)
                } else if let number = episodeEntry.valueIfPresent(at: "episode_number", type: Double.self) {
                    episodeNumber = number
                } else { episodeNumber = 1 }
                let episodeTitle = episodeEntry.valueIfPresent(at: "title", type: String.self)
                let episodeSynopsis = episodeEntry.valueIfPresent(at: "description", type: String.self)
                
                let episodeNumberFormatter = NumberFormatter()
                episodeNumberFormatter.minimumFractionDigits = 0
                episodeNumberFormatter.maximumFractionDigits = 3
                episodeNumberFormatter.numberStyle = .decimal
                
                // Assemble the episode name
                // Formatted as: \(Episode Number) - \(Episode Title) - \(Season Title)
                let episodeName = ([
                    episodeNumberFormatter.string(from: NSNumber(value: episodeNumber)),
                    episodeTitle,
                    title
                ] as [CustomStringConvertible?])
                    .compactMap { $0?.description }
                    .joined(separator: " - ")
                
                var sourcesEntries = [NSDictionary]()
                
                // Retrieve the sources entry
                if let sources = episodeEntry.valueIfPresent(at: "sources", type: [NSDictionary].self) {
                    sourcesEntries.append(contentsOf: sources)
                }
                
                // Add the retrieve url to the root entry
                if let retrieveUrls = episodeEntry["retrieve_url"] {
                    let rootSource = NSMutableDictionary()
                    rootSource["source"] = "fa"
                    rootSource["language"] = "subs"
                    rootSource["retrieve_url"] = retrieveUrls
                    sourcesEntries.append(rootSource)
                }
                
                // Extract source identifiers
                return try sourcesEntries.flatMap {
                    sourceEntry -> [(EpisodeLink, Anime.AdditionalEpisodeLinkInformation)] in
                    let sourceName = try sourceEntry.value(at: "source", type: String.self)
                    let sourceLanguage = try sourceEntry.value(at: "language", type: String.self)
                    
                    // Use retrieve resource identifier as episode identifier
                    let retrieveIdentifiers: [String]
                    if let singleRetrieveIdentifier = sourceEntry.valueIfPresent(at: "retrieve_url", type: String.self) {
                        retrieveIdentifiers = [ singleRetrieveIdentifier ]
                    } else {
                        retrieveIdentifiers = try sourceEntry.value(at: "retrieve_url", type: [String].self)
                    }
                    
                    return retrieveIdentifiers.map {
                        identifier -> EpisodeLink in
                        // By default, the server identifier is the source name
                        var serverIdentifier: Anime.ServerIdentifier = sourceName
                            .replacingOccurrences(of: ":", with: "-")
                            .uppercased()
                        serverIdentifier += ":\(sourceLanguage)"
                        
                        // Annotate the server name at the end of the server identifier
                        if let inferredServerName = {
                            () -> String? in
                            var parser = URLComponents()
                            parser.percentEncodedQuery = identifier
                            return parser.queryItems?.first { $0.name == "name" }?
                                .value?
                                .replacingOccurrences(of: ":", with: "-")
                        }() { serverIdentifier += ":\(inferredServerName)" }
                        
                        let episodeLink = EpisodeLink(
                            identifier: identifier,
                            name: episodeName,
                            server: serverIdentifier,
                            parent: animeLink
                        )
                        
                        return episodeLink
                    } .map {
                        link -> (EpisodeLink, Anime.AdditionalEpisodeLinkInformation) in
                        // Append the additional information to the episode link
                        let additionalInformation = Anime.AdditionalEpisodeLinkInformation(
                            parent: link,
                            synopsis: episodeSynopsis,
                            season: title,
                            episodeNumber: episodeNumber.rounded() == episodeNumber ? Int(episodeNumber) : nil,
                            title: episodeTitle
                        )
                        return (link, additionalInformation)
                    }
                }
            }
        
        // Empty retrieved episodes list
        guard !retrievedEpisodes.isEmpty else {
            throw NineAnimatorError.responseError("No episodes found for this anime")
        }
        
        var episodes = Anime.EpisodesCollection()
        var episodeAdditionalInformationMap = [EpisodeLink: Anime.AdditionalEpisodeLinkInformation]()
        var serverNameMap = [Anime.ServerIdentifier: String]()
        
        // Sort by server
        for (link, attribute) in retrievedEpisodes {
            episodeAdditionalInformationMap[link] = attribute
            var originalCollection = episodes[link.server] ?? []
            if !originalCollection.contains(where: { $0.name == link.name }) {
                originalCollection.append(link)
            } else {
                Log.info("[WonderfulSubs] Found a repeating episode \"%@\" under server %@", link.name, link.server)
            }
            episodes[link.server] = originalCollection
        }
        
        // Generate server name map
        for (serverIdentifier, _) in episodes {
            let serverInformation = serverIdentifier.split(separator: ":")
            let streamType = String(serverInformation[1])
            let streamingServiceName = serverInformation.count > 2 ? String(serverInformation[2]) : "WonderfulSubs - \(serverInformation[0])"
            
            serverNameMap[serverIdentifier] = "(\(streamType)) \(streamingServiceName)"
        }
        
        // At last, construct the anime object
        return Anime(
            animeLink,
            alias: alias,
            additionalAttributes: [:],
            description: description,
            on: serverNameMap,
            episodes: episodes,
            episodesAttributes: episodeAdditionalInformationMap
        )
    }
}
