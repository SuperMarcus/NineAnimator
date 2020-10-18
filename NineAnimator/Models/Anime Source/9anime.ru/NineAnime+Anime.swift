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

extension NASourceNineAnime {
    // Map 9anime attribute key to NineAnimator.Anime.AttributeKey
    fileprivate static let attributeKeyMap = [
        "date aired": Anime.AttributeKey.airDate
    ]
    
    fileprivate static let scoresRegex = try! NSRegularExpression(
        pattern: "([\\d.]+)\\s*\\/\\s*([\\d,.]+)",
        options: []
    )
    
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestDescriptor().thenPromise {
            _ in self.animeInfo(in: link.link)
        } .thenPromise {
            animePageInfo in
            self.availableServers(
                of: animePageInfo.siteId,
                refererLink: animePageInfo.animeLink.link
            ) .then { (animePageInfo, $0) }
        } .then {
            animePageInfo, serverEpisodeInfo in
            // Map episodes to server-episodes
            let serverEpisodeMap = serverEpisodeInfo.servers.reduce(into: Anime.EpisodesCollection()) {
                collection, server in
                collection[server.id] = serverEpisodeInfo.episodes.compactMap {
                    episodeInfo in EpisodeLink(
                        identifier: episodeInfo.link.path,
                        name: episodeInfo.name,
                        server: server.id,
                        parent: animePageInfo.animeLink
                    )
                }
            }
            
            let availableServerList = serverEpisodeInfo.servers.reduce(into: [Anime.ServerIdentifier: String]()) {
                $0[$1.id] = $1.name
            }
            
            // Additional attributes
            var animeAttributes = animePageInfo.attributes.reduce(into: [Anime.AttributeKey: Any]()) {
                result, attribute in
                if attribute.key.lowercased() == "scores" {
                    if let scoreMatch = NASourceNineAnime.scoresRegex.firstMatch(in: attribute.value) {
                        if let rating = Float(scoreMatch[1]) {
                            result[Anime.AttributeKey.rating] = rating
                            result[Anime.AttributeKey.ratingScale] = Float(10)
                        }
                        
                        if let votes = Int(scoreMatch[2].replacingOccurrences(of: ",", with: "")) {
                            result["Number of Votes"] = votes
                        }
                    }
                    
                    return
                }
                
                result[NASourceNineAnime.attributeKeyMap[attribute.key] ?? attribute.key] = attribute.value
            }
            
            // Private attributes
            animeAttributes[AnimeAttributeKey.animePageInfo] = animePageInfo
            
            return Anime(
                animePageInfo.animeLink,
                alias: animePageInfo.alias,
                additionalAttributes: animeAttributes,
                description: animePageInfo.synopsis,
                on: availableServerList,
                episodes: serverEpisodeMap
            )
        }
    }
    
    /// Retrieve anime info from the anime page
    func animeInfo(in pageUrl: URL) -> NineAnimatorPromise<AnimeInfo> {
        self.requestManager.request(
            url: pageUrl,
            handling: .browsing
        ) .responseBowl
          .then {
            bowl in
            // Basic Anime Info
            let infoContainer = try bowl.select("#info")
            
            let animeArtworkString = try infoContainer.select("img").attr("src")
            let animeArtworkUrl = URL(
                protocolRelativeString: animeArtworkString,
                relativeTo: pageUrl
            ) ?? NineAnimator.placeholderArtworkUrl
            
            let animeTitle = try infoContainer
                .select(".title")
                .text()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let animeAlias = try infoContainer
                .select(".alias")
                .text()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let animeSynopsis = try infoContainer
                .select(".shorting")
                .text()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let animeLink = AnimeLink(
                title: animeTitle,
                link: pageUrl,
                image: animeArtworkUrl,
                source: self
            )
            
            // Anime Identifier
            let playerContainer = try bowl.select(".watchpage")
            let animeId = try playerContainer.attr("data-id")
            
            // Metadata
            let animePageAttributes = try bowl.select(".meta>*>div").reduce(into: [String: String]()) {
                dict, currentElement in
                do {
                    if let metaValueSpan = try currentElement.select("span").first() {
                        // Get value then key
                        let metaValue = try metaValueSpan.text().trimmingCharacters(in: .whitespacesAndNewlines)
                        try metaValueSpan.remove()
                        var metaKey = try currentElement.text().trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if metaKey.hasSuffix(":") {
                            metaKey.removeLast()
                            metaKey = metaKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        
                        dict[metaKey] = metaValue
                    }
                } catch {
                    Log.error("[NASourceNineAnime] Unable to parse a metadata (%@) because of an error: %@", currentElement, error)
                }
            }
            
            return AnimeInfo(
                animeLink: animeLink,
                alias: animeAlias,
                synopsis: animeSynopsis,
                siteId: animeId,
                attributes: animePageAttributes
            )
        }
    }
    
    /// Retrieve the available servers and episodes of an anime
    func availableServers(of animeId: String, refererLink: URL) -> NineAnimatorPromise<AnimeServerList> {
        if let cachedServerList = self.retrieveServerInfoCache(animeId) {
            return .success(cachedServerList)
        }
        
        return self.requestManager.request(
            "ajax/anime/servers",
            handling: .ajax,
            parameters: [
                "id": animeId,
                "ep": "",
                "episode": ""
            ],
            headers: [
                "Accept": "text/html, */*; q=0.01",
                "Referer": refererLink.absoluteString
            ]
        ) .responseBowl
          .then {
            bowl -> AnimeServerList in
            let serverList = try bowl
                .select(".servers>span")
                .map {
                    serverElement in AnimeServer(
                        id: try serverElement.attr("data-id"),
                        elementId: try serverElement.attr("id"),
                        name: try serverElement.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            
            let episodeList = try bowl
                .select(".episodes a")
                .reduce(into: [EpisodeInfo]()) {
                    list, episodeElement in
                    // Read and decode the sources attribute
                    let sourcesAttributeValue = try episodeElement.attr("data-sources")
                    guard let sourcesAttributeData = sourcesAttributeValue.data(using: .utf8),
                       let decodedSources = try JSONSerialization.jsonObject(
                        with: sourcesAttributeData,
                        options: []
                       ) as? [StreamServerID: EpisodeResourceID] else {
                        return
                    }
                    
                    // Other episode info
                    let episodePageLink = try URL(
                        protocolRelativeString: try episodeElement.attr("href"),
                        relativeTo: refererLink
                    ).tryUnwrap()
                    
                    let episodeName = try episodeElement
                        .text()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let episodeNameNormalized = try episodeElement
                        .attr("data-name-normalized")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let episodeInfo = EpisodeInfo(
                        name: episodeName,
                        normalizedName: episodeNameNormalized,
                        link: episodePageLink,
                        resourceMap: decodedSources
                    )
                    
                    list.append(episodeInfo)
                }
            
            return AnimeServerList(
                servers: serverList,
                episodes: episodeList
            )
        } .then {
            list in
            // Store in cache
            self.storeServerInfoCache(animeId, caching: list)
            return list
        }
    }
}

// MARK: - Data Structs
extension NASourceNineAnime {
    struct AnimeInfo {
        var animeLink: AnimeLink
        var alias: String
        var synopsis: String
        var siteId: String
        var attributes: [String: String]
    }
    
    struct AnimeServerList {
        var servers: [AnimeServer]
        var episodes: [EpisodeInfo]
    }
    
    struct AnimeServer: Hashable {
        var id: StreamServerID
        var elementId: String
        var name: String
    }
    
    struct EpisodeInfo {
        var name: String
        var normalizedName: String
        var link: URL
        var resourceMap: [StreamServerID: EpisodeResourceID]
    }
    
    typealias StreamServerID = String
    typealias EpisodeResourceID = StreamServerID
}
