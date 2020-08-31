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

extension NASourceAnimePahe {
    struct ReleaseResponse: Codable {
        var total: Int
        var per_page: Int
        var last_page: Int
        var from: Int?
        var to: Int?
        var data: [ReleaseEpisodeItem]?
    }
    
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager.request(url: link.link, handling: .browsing).responseString.thenPromise {
            responseContent -> NineAnimatorPromise<(ClosedRange<Int>, Int, String, String, [Anime.AttributeKey: Any], AnimeLink)> in
            let bowl = try SwiftSoup.parse(responseContent)
            
            // Find the anime identifier with a regex
            let animeIdentifierRegex = try NSRegularExpression(pattern: "anime-(\\d+)", options: [ .caseInsensitive ])
            let animeIdentifier = try (animeIdentifierRegex.firstMatch(in: responseContent)?.firstMatchingGroup).tryUnwrap(.responseError("Unable to find the matching anime identifier on animepahe.com"))
            
            // Find the synopsis in the container
            let animeSynopsis = try bowl
                .select("div.anime-synopsis")
                .text()
                .replacingOccurrences(of: "\\n+", with: "\n", options: [.regularExpression])
            var animeAttributes = [Anime.AttributeKey: Any]()
            
            // Find the HD anime poster
            let animePosterLink = try bowl.select(".anime-poster img").attr("src")
            let animePosterUrl = URL(string: animePosterLink) ?? link.image
            let reconstructedAnimeLink = AnimeLink(
                title: link.title,
                link: link.link,
                image: animePosterUrl,
                source: self
            )
            
            do {
                // Iterate through the anime attributes and try to find the air date
                let animeAiringDateAttribute = try bowl
                    .select("div.anime-info>p")
                    .first {
                        attribute -> Bool in try attribute
                            .select("strong")
                            .text()
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .lowercased() == "aired:"
                }.tryUnwrap()
                
                // Remove the "Aired: " and trim the value
                try animeAiringDateAttribute.select("strong").remove()
                let airDate = try animeAiringDateAttribute.text().trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Stores the air date as an attribute
                if !airDate.isEmpty { animeAttributes[.airDate] = airDate }
            } catch {
                // No anime air date found, which is fine.
            }
            
            // Request the episodes on the first page in ascending order
            return self.lookupEpisodeRange(animeIdentifier: animeIdentifier).then { range, perPageEntries in (
                range,
                perPageEntries,
                animeIdentifier,
                animeSynopsis,
                animeAttributes,
                reconstructedAnimeLink
            ) }
        } .then {
            episodeRange, perPageEntries, animeIdentifier, animeSynopsis, animeAttributes, reconstructedAnimeLink -> Anime in
            // Using a little trick here: since animepahe lists episodes in pages, it is
            // slow and quite unreasonable to interate through all pages. Therefore, stores
            // the episode number and page number in the episode identifeir, and then
            // uses that information to request the real episode identifier when requesting
            // the Episode object.
            let episodeIdentifiers: [(episodeNumber: Int, page: Int)] = episodeRange
                .map { ($0, ($0 / perPageEntries) + 1) }
            
            // The three known providers
            let staticProviders = [
//                "openload": "OpenLoad",
//                "streamango": "Streamango",
                "kwik": "Kiwik"
            ]
            
            // Construct the anime object
            return Anime(
                reconstructedAnimeLink,
                additionalAttributes: animeAttributes,
                description: animeSynopsis,
                on: staticProviders,
                episodes: Dictionary(
                    uniqueKeysWithValues: try staticProviders.map {
                        providerPair in (providerPair.key, try episodeIdentifiers.map {
                            identifier in EpisodeLink(
                                identifier: try formEncode([
                                    "anime": animeIdentifier,
                                    "episode": identifier.episodeNumber,
                                    "page": identifier.page
                                ]),
                                name: String(identifier.episodeNumber),
                                server: providerPair.key,
                                parent: reconstructedAnimeLink
                            )
                        })
                    }
                )
            )
        }
    }
    
    /// Lookup anime episode range and the per-page parameter
    fileprivate func lookupEpisodeRange(animeIdentifier: String) -> NineAnimatorPromise<(range: ClosedRange<Int>, perPage: Int)> {
        self.requestManager.request(
            "/api",
            handling: .ajax,
            query: [
                "m": "release",
                "id": animeIdentifier,
                "l": 30,
                "sort": "episode_asc",
                "page": 1
            ]
        ) .responseDictionary
          .then {
            try DictionaryDecoder().decode(
                ReleaseResponse.self,
                from: $0
            )
        } .thenPromise {
            releaseFirstPage in
            let firstPageData = try releaseFirstPage.data
                .tryUnwrap(.responseError("No episodes were found in this anime"))
            let firstEpisodeNumber = try firstPageData.first
                .tryUnwrap(.responseError("No episodes were found in this anime"))
                .episode
            
            // Release only contains one page
            if releaseFirstPage.last_page == 1 {
                let lastEpisodeItem = try firstPageData.last
                    .tryUnwrap(.responseError("No episodes were found in this anime"))
                let lastEpisodeNumber = max(
                    lastEpisodeItem.episode,
                    lastEpisodeItem.episode2 ?? 0
                )
                return .success((
                    (firstEpisodeNumber...lastEpisodeNumber),
                    releaseFirstPage.per_page
                ))
            }
            
            return self.requestManager.request(
                "/api",
                handling: .ajax,
                query: [
                    "m": "release",
                    "id": animeIdentifier,
                    "l": 30,
                    "sort": "episode_asc",
                    "page": releaseFirstPage.last_page
                ]
            ) .responseDictionary
              .then {
                try DictionaryDecoder().decode(
                    ReleaseResponse.self,
                    from: $0
                )
            } .then {
                releaseLastPage in
                let lastPageData = try releaseLastPage.data
                    .tryUnwrap(.responseError("No episodes were found in this anime"))
                let lastEpisodeItem = try lastPageData.last
                    .tryUnwrap(.responseError("No episodes were found in this anime"))
                let lastEpisodeNumber = max(
                    lastEpisodeItem.episode,
                    lastEpisodeItem.episode2 ?? 0
                )
                return (
                    firstEpisodeNumber...lastEpisodeNumber,
                    releaseFirstPage.per_page
                )
            }
        }
    }
}
