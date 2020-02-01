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

extension NASourceKissanime {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        request(browseUrl: link.link).then {
            content in
            let bowl = try SwiftSoup.parse(content)
            
            // Fetch all available episode entries
            let episodeEntries = try bowl.select("table.listing tr").compactMap {
                episodeContainer -> (name: String, path: String, date: String)? in
                do {
                    let resourceLinkContainer = try episodeContainer
                        .select("td>a")
                        .first()
                        .tryUnwrap()
                    let episodeAddedDate = try episodeContainer
                        .select("td")
                        .last()
                        .tryUnwrap()
                        .ownText()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let episodePath = try resourceLinkContainer.attr("href")
                    let episodeName = resourceLinkContainer
                        .ownText()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return (episodeName, episodePath, episodeAddedDate)
                } catch { return nil }
            }
            
            var episodeCollection = Anime.EpisodesCollection()
            var episodeAttributes = [EpisodeLink: Anime.AdditionalEpisodeLinkInformation]()
            var animeAttributes = [Anime.AttributeKey: Any]()
            
            // Iterates the episode links
            for (serverIdentifier, _) in NASourceKissanime.knownServers {
                var currentCollection = [EpisodeLink]()
                for (episodeName, episodePath, episodeAddedDate) in episodeEntries {
                    let inferredEpisodeNumber = self.inferEpisodeNumber(fromName: episodeName)
                    var conventionalEpisodeName = episodeName
                    
                    // Modify the episode name according to NineAnimator's naming convension
                    if let eNumber = inferredEpisodeNumber {
                        conventionalEpisodeName = "\(eNumber) - \(episodeName)"
                    }
                    
                    // Create and save the episode link
                    let currentEpisodeLink = EpisodeLink(
                        identifier: episodePath,
                        name: conventionalEpisodeName,
                        server: serverIdentifier,
                        parent: link
                    )
                    currentCollection.append(currentEpisodeLink)
                    
                    // Create and save the episode attributes
                    let currentEpisodeAttribute = Anime.AdditionalEpisodeLinkInformation(
                        parent: currentEpisodeLink,
                        synopsis: nil,
                        airDate: episodeAddedDate,
                        season: nil,
                        episodeNumber: inferredEpisodeNumber,
                        title: episodeName
                    )
                    episodeAttributes[currentEpisodeLink] = currentEpisodeAttribute
                }
                // Save the collection of episode links
                episodeCollection[serverIdentifier] = currentCollection.reversed()
            }
            
            let animeAttributesEntries = try bowl.select(".bigBarContainer .barContent p")
            var collectedAnimeAttributes = [String: String]()
            
            // Iterates through the attribute elements
            for (offset, animeAttributeContainer) in animeAttributesEntries.enumerated() {
                do {
                    let attributeKeyElement = try animeAttributeContainer
                        .select("span.info")
                        .first()
                        .tryUnwrap()
                    let attributeKey = {
                        () -> String in
                        var rawKey = attributeKeyElement.ownText()
                        if rawKey.hasSuffix(":") {
                            rawKey.removeLast()
                        }
                        return rawKey
                            .lowercased()
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }()
                    
                    // Removes the key element from the hierarchy
                    try attributeKeyElement.remove()
                    var attributeValue = try animeAttributeContainer
                        .text()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // The last of all, summary
                    if attributeKey == "summary" {
                        attributeValue = try animeAttributesEntries[offset...]
                            .map { try $0.text().trimmingCharacters(in: .whitespacesAndNewlines) }
                            .joined(separator: "\n")
                    }
                    
                    // Stores the key-value pair
                    collectedAnimeAttributes[attributeKey] = attributeValue
                } catch { continue }
            }
            
            let animeSynopsis = collectedAnimeAttributes["summary"] ?? "No synopsis found for this anime."
            let animeAlternativeNames = collectedAnimeAttributes["other name"] ?? ""
            
            if let airDate = collectedAnimeAttributes["date aired"] {
                animeAttributes[.airDate] = airDate
            }
            
            // Construct the anime object
            return Anime(
                link,
                alias: animeAlternativeNames,
                additionalAttributes: animeAttributes,
                description: animeSynopsis,
                on: NASourceKissanime.knownServers,
                episodes: episodeCollection,
                episodesAttributes: episodeAttributes
            )
        }
    }
    
    func processArtworkUrl(_ url: URL) -> URL {
        do {
            var components = try URLComponents(url: url, resolvingAgainstBaseURL: true).tryUnwrap()
            
            // Change http to https
            if components.scheme == "http" {
                components.scheme = "https"
            }
            
            return try components.url.tryUnwrap()
        } catch { return url }
    }
}
