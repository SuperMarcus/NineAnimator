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
import NineAnimatorCommon
import SwiftSoup

extension NASourceFourAnime {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        (self.isAnimeLink(url: link.link) ? .success(link) : self.resolveAnimeLink(
            from: link.link,
            artworkUrl: link.image
        )) .thenPromise {
            resolvedAnimeLink in self.requestManager.request(
                url: resolvedAnimeLink.link,
                handling: .browsing
            ) .responseBowl // Resolves to a SwiftSoup bowl and combine with the newly resolved link
              .then { (resolvedAnimeLink, $0) }
        } .then {
            resolvedAnimeLink, bowl in
            let animeArtworkUrl = URL(
                string: try bowl.select(".cover>img").attr("src"),
                relativeTo: resolvedAnimeLink.link
            ) ?? resolvedAnimeLink.image
            let animeTitle = try bowl.select(".content p").text()
            let reconstructedAnimeLink = AnimeLink(
                title: animeTitle,
                link: resolvedAnimeLink.link,
                image: animeArtworkUrl,
                source: self
            )
            
            // Obtain list of episodes and their links
            let episodeNamesAndLinks = try bowl.select("ul.episodes>li").reduce(into: [(String, String)]()) {
                totalCollection, currentContainer in
                let episodeName = try currentContainer
                    .text()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let episodeLink = try currentContainer.select("a").attr("href")
                
                totalCollection.append((episodeName, episodeLink))
            }
            
            // Add each episode to every server
            var episodeCollection = Anime.EpisodesCollection()
            for (serverIdentifier, _) in NASourceFourAnime.knownServers {
                var currentCollection = [EpisodeLink]()
                
                for (episodeName, episodeLink) in episodeNamesAndLinks {
                    currentCollection.append(.init(
                        identifier: episodeLink,
                        name: episodeName,
                        server: serverIdentifier,
                        parent: link
                    ))
                }
                episodeCollection[serverIdentifier] = currentCollection
            }
            
            // Information
            let animeSynopsis = try bowl
                .select("div#description-mob")
                .text()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(
                    of: "\\n+",
                    with: "\n",
                    options: [.regularExpression]
                )
                .replacingOccurrences(
                    of: "^Description\\s",
                    with: "",
                    options: [.regularExpression]
                )
            
            // Attributes
            var additionalAttributes = [Anime.AttributeKey: Any]()
            let detailContainers = try bowl.select("div.info div.detail")
            
            for container in detailContainers {
                let attributeNameContainer = try container.select(".title-side")
                let attributeName = try attributeNameContainer.text()
                try attributeNameContainer.remove()
                let attributeValue = try container
                    .text()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if attributeName.lowercased().contains("release date") {
                    additionalAttributes[.airDate] = attributeValue
                }
            }
            
            return Anime(
                reconstructedAnimeLink,
                alias: "",
                additionalAttributes: additionalAttributes,
                description: animeSynopsis,
                on: NASourceFourAnime.knownServers,
                episodes: episodeCollection,
                episodesAttributes: [:]
            )
        }
    }
    
    /// Attempts to resolve the AnimeLink from an episode page URl
    private func resolveAnimeLink(from url: URL, artworkUrl: URL? = nil) -> NineAnimatorPromise<AnimeLink> {
        self.requestManager
            .request(url: url, handling: .browsing)
            .responseBowl
            .then {
                bowl in
                let animeTitleLink = try bowl.select("a#titleleft")
                let animeLinkString = try animeTitleLink.attr("href")
                let animeLinkURL = try URL(
                    string: animeLinkString,
                    relativeTo: url
                ).tryUnwrap(.responseError("Cannot find a valid link to the anime page"))
                let animeArtworkURL = artworkUrl ?? NineAnimator.placeholderArtworkUrl
                let animeTitle = try animeTitleLink.text()
                
                // Construct AnimeLink
                return AnimeLink(
                    title: animeTitle,
                    link: animeLinkURL,
                    image: animeArtworkURL,
                    source: self
                )
            }
    }
    
    /// Checks if the provided link points to an anime page
    private func isAnimeLink(url: URL) -> Bool {
        url.pathComponents.contains("anime")
    }
}
