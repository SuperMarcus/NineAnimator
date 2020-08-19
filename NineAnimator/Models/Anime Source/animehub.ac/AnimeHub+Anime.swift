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

extension NASourceAnimeHub {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager.request(
            url: link.link,
            handling: .browsing
        ).responseString.then {
            responseContent -> Anime in
            let bowl = try SwiftSoup.parse(responseContent)
            
            let animeTitle = try bowl.select("h1.dc-title").text()
            
            let animeArtworkURL = try URL(
                string: bowl.select("dc-thumb > img").attr("src")
            ) ?? link.image
            
            let reconstructedAnimeLink = AnimeLink(
                title: animeTitle,
                link: link.link,
                image: animeArtworkURL,
                source: self
            )
            
            // Obtain list of episodes
            let episodeList = try bowl.select("#episodes-sv-1 > li").compactMap {
                episodeContainer -> (identifier: String, episodeName: String) in
                let episodeIndentifier = try episodeContainer.select("div.sli-name > a").attr("href")
                
                let episodeName = try episodeContainer.select("div.sli-name > a")
                    .text()
                    .replacingOccurrences(of: "Episode ", with: "")
                return(episodeIndentifier, episodeName)
            }
            
            if episodeList.isEmpty {
                throw NineAnimatorError.responseError("No episodes found for this anime")
            }
            
            // Collection of episodes
            var episodeCollection = Anime.EpisodesCollection()
            
            // We incorrectly assume each server contains every episode
            for (serverIdentifier, _) in NASourceAnimeHub.knownServers {
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
            let animeSynopsis = try bowl.select("div.dci-desc").text()
            
            // Attributes
            var additionalAnimeAttributes = [Anime.AttributeKey: Any]()
            
            let date = try bowl.select("div.dcis.dcis-05")
                .text()
                .replacingOccurrences(of: "Released: ", with: "")
            additionalAnimeAttributes[.airDate] = date
            
            let rating = try bowl.select("#vote_percent").text()
            additionalAnimeAttributes[.rating] = Float(rating) ?? 0
            additionalAnimeAttributes[.ratingScale] = Float(5.0)
            
            return Anime(
                reconstructedAnimeLink,
                alias: "",
                additionalAttributes: additionalAnimeAttributes,
                description: animeSynopsis,
                on: NASourceAnimeHub.knownServers,
                episodes: episodeCollection
            )
        }
    }
}
