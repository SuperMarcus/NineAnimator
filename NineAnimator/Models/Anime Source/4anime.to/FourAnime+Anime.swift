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

extension NASourceFourAnime {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager.request(
            url: link.link,
            handling: .browsing
        ) .responseString.then {
            responseContent -> Anime in
            let bowl = try SwiftSoup.parse(responseContent)
            let animeTitle = try bowl.select(".content p").text()
            let animeArtworkUrl = URL(
                string: try bowl.select(".cover>img").attr("src")
            ) ?? link.image
            let reconstructedAnimeLink = AnimeLink(
                title: animeTitle,
                link: link.link,
                image: animeArtworkUrl,
                source: self
            )
            
            // Obtain the list of episodes
            let episodes = try bowl.select("ul.episodes>li").reduce(into: [EpisodeLink]()) {
                collection, container in
                let episodeName = try container
                    .text()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let episodeLink = try container.select("a").attr("href")
                
                collection.append(.init(
                    identifier: episodeLink,
                    name: episodeName,
                    server: NASourceFourAnime.FourAnimeStream,
                    parent: reconstructedAnimeLink
                ))
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
                on: [ NASourceFourAnime.FourAnimeStream: "4anime" ],
                episodes: [ NASourceFourAnime.FourAnimeStream: episodes ],
                episodesAttributes: [:]
            )
        }
    }
}
