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

extension NASourceAnimeFlv {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager.request(
            url: link.link, handling: .browsing)
            .responseString
            .then {
            responseContent -> Anime in
            let bowl = try SwiftSoup.parse(responseContent)
            let animeTitle = try bowl.select("h1.Title").text()
            let animeArtworkURL = try URL(
                string: bowl.select("figure.Image > img").attr("src"),
                relativeTo: self.endpointURL
            ) ?? link.image
            let reconstructedAnimeLink = AnimeLink(
                title: animeTitle,
                link: link.link,
                image: animeArtworkURL,
                source: self
            )
            // List of episode
            let episodeList = try bowl.select("li.Episode").compactMap {
                episodeElement -> (identifier: String, episodeNumber: String) in
                let episodeIdentifier = "\(self.endpointURL)\(try episodeElement.select("a").attr("href"))"
                let episodeNumber = try episodeElement
                    .select("a")
                    .text()
                    .replacingOccurrences(of: animeTitle, with: "")
                return (episodeIdentifier, episodeNumber)
            } .reversed()
            
            if episodeList.isEmpty {
                throw NineAnimatorError.responseError("No episodes found for this anime")
            }
            
            // Collection of episodes
            var episodeCollection = Anime.EpisodesCollection()
            
            // We incorrectly assume each server contains every episode
            for (serverIdentifier, _) in NASourceAnimeFlv.knownServers {
                var currentCollection = [EpisodeLink]()
                
                for (episodeIdentifier, episodeName) in episodeList {
                    let currentEpisodeLink = EpisodeLink(
                        identifier: episodeIdentifier,
                        name: episodeName,
                        server: serverIdentifier,
                        parent: reconstructedAnimeLink
                    )
                    currentCollection.append(currentEpisodeLink)
                }
                
                episodeCollection[serverIdentifier] = currentCollection.reversed()
            }
            
            // Information
                let animeSynopsis = try bowl.select("header > p:nth-child(3)").text().replacingOccurrences(of: "Sinopsis: ", with: "")
            
            // Attributes
            var additionalAnimeAttributes = [Anime.AttributeKey: Any]()
            
            let rating = try bowl.select("#votes_prmd").text()
            additionalAnimeAttributes[.rating] = Float(rating) ?? 0
            additionalAnimeAttributes[.ratingScale] = Float(5.0)
            
            return Anime(
                reconstructedAnimeLink,
                alias: "",
                additionalAttributes: additionalAnimeAttributes,
                description: animeSynopsis,
                on: NASourceAnimeFlv.knownServers,
                episodes: episodeCollection
            )
        }
    }
}
