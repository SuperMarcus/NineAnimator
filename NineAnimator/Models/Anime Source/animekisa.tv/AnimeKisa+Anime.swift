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
import SwiftSoup

extension NASourceAnimeKisa {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        if let expSelf = self as? ExperimentalSource {
            return expSelf._anime(from: link)
        }
        
        return self.requestManager.request(
            url: link.link,
            handling: .browsing
        ) .responseString.then {
            response in
            let bowl = try SwiftSoup.parse(response)
            let artworkUrl = URL(
                string: try bowl
                    .select("div.infobox div.infopicbox img.posteri")
                    .attr("src"),
                relativeTo: link.link
            ) ?? link.image
            
            // Reconstruct the AnimeLink with the new artwork URL
            let reconstructedAnimeLink = AnimeLink(
                title: link.title,
                link: link.link,
                image: artworkUrl,
                source: self
            )
            
            // Fetch the anime description from the .infodes2 element
            let animeDescription: String = {
                do {
                    let d = try bowl
                        .select("div.infodes2")
                        .first()
                        .tryUnwrap()
                        .ownText()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if d.isEmpty { return nil }
                    return d
                } catch { return nil }
            }() ?? "No synopsis found for this anime"
            
            // Obtain attributes
            var animeAttributes = [(String, String?)]()
            for attributeElement in try bowl.select("div.infodes2>div") {
                if attributeElement.hasClass("textd") {
                    let key = try attributeElement
                        .text()
                        .lowercased()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    animeAttributes.append((key, nil))
                } else if attributeElement.hasClass("textc"),
                    let currentItem = animeAttributes.popLast() {
                    animeAttributes.append((
                        currentItem.0,
                        try attributeElement
                            .text()
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
            }
            let animeAttributeMap = Dictionary(uniqueKeysWithValues: animeAttributes.compactMap {
                i -> (String, String)? in
                if let v = i.1 {
                    return (i.0, v)
                } else { return nil }
            })
            
            // List of episode
            let episodeList = try bowl.select("div.infoepbox>a").compactMap {
                episodeElement -> (identifier: String, episodeNumber: String) in
                let episodeIdentifier = try episodeElement.attr("href")
                let episodeNumber = try episodeElement
                    .select(".infoept2,.infoept2r")
                    .text()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (episodeIdentifier, episodeNumber)
            } .reversed()
            
            if episodeList.isEmpty {
                throw NineAnimatorError.responseError("No episode found for this anime")
            }
            
            // Collection of episodes
            var episodeCollection = Anime.EpisodesCollection()
            for (serverIdentifier, _) in NASourceAnimeKisa.knownServers {
                episodeCollection[serverIdentifier] = episodeList.map {
                    item in EpisodeLink(
                        identifier: item.identifier,
                        name: item.episodeNumber,
                        server: serverIdentifier,
                        parent: reconstructedAnimeLink
                    )
                }
            }
            
            // Construct the Anime object
            return Anime(
                reconstructedAnimeLink,
                alias: animeAttributeMap["alias:"] ?? "",
                additionalAttributes: [:],
                description: animeDescription,
                on: NASourceAnimeKisa.knownServers,
                episodes: episodeCollection,
                episodesAttributes: [:]
            )
        }
    }
}

extension NASourceAnimeKisa.ExperimentalSource {
    static let episodeRegex = try! NSRegularExpression(
        pattern: "Episode\\s?(\\d+)",
        options: .caseInsensitive
    )
    
    func _anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager.request(
            url: link.link,
            handling: .browsing
        ) .responseString.then {
            response in
            let bowl = try SwiftSoup.parse(response)
            
            let defaultServerName = "adless"
            let artworkUrl = URL(
                string: try bowl
                    .select(".image-box > img")
                    .attr("src"),
                relativeTo: link.link
            ) ?? link.image
            
            let reconstructedAnimeLink = AnimeLink(
                title: link.title,
                link: link.link,
                image: artworkUrl,
                source: self
            )
            
            let episodes = try bowl.select("a.an").reduce(into: [EpisodeLink]()) {
                collection, container in
                let episodeName = try NASourceAnimeKisa.ExperimentalSource
                    .episodeRegex
                    .firstMatch(in: try container.select("div > .info-box").text())
                    .tryUnwrap()
                    .firstMatchingGroup
                    .tryUnwrap()
                
                let episodeLink = try container.attr("href")
                
                collection.append(.init(
                    identifier: episodeLink,
                    name: episodeName,
                    server: defaultServerName,
                    parent: reconstructedAnimeLink
                ))
            }
            
            return Anime(
                reconstructedAnimeLink,
                alias: "",
                additionalAttributes: [:],
                description: "No synopsis found for this anime",
                on: [ defaultServerName: "\u{0048}\u{0065}\u{006e}\u{0074}\u{0061}\u{0069}\u{004b}\u{0069}\u{0073}\u{0061}" ],
                episodes: [ defaultServerName: episodes.reversed() ],
                episodesAttributes: [:]
            )
        }
    }
}
