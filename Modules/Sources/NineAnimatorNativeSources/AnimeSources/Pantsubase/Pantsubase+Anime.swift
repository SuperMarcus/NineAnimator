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

extension NASourcePantsubase {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        requestManager.request(url: link.link)
            .responseBowl
            .then {
                bowl in
                let animeTitle = try bowl.select("h1.mb-1").text()
                
                var animeCover = try bowl.select("img.mt-3").attr("src")
                
                // Add https:// prefix if required
                if animeCover.hasPrefix("//") {
                    animeCover = "https:" + (try animeCover
                        .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                        .tryUnwrap(.urlError))
                }
                
                let animeCoverURL = try URL(string: animeCover)
                    .tryUnwrap()
                
                // Create the reconstructed anime link
                let reconstructedAnimeLink = AnimeLink(
                    title: animeTitle,
                    link: link.link,
                    image: animeCoverURL,
                    source: self
                )
                
                // Obtain list of episodes and their links
                let episodeNamesAndLinks = try bowl.select("ul.episode > li").reduce(into: [(String, String)]()) {
                    totalCollection, currentBowl in
                    // Remove the "EP" thing
                    try currentBowl.select("div.name > span").remove()
                    let episodeName = try currentBowl
                        .select("div.name")
                        .text()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let episodeLink = try currentBowl
                        .select("a")
                        .attr("href")
                    totalCollection.append((episodeName, episodeLink))
                }.reversed()
                
                // Add each episode to every server
                var episodeCollection = Anime.EpisodesCollection()
                for (serverIdentifier, _) in NASourcePantsubase.knownServers {
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
                
                // Get anime info
                let animeSynopsis = (try bowl
                    .select("div.info > ul")[safe: 3]?
                    .text()) ?? ""
                
                // Additional Anime Attributes
                var additionalAttributes = [Anime.AttributeKey: Any]()
                
                let airDate = (try bowl
                    .select("div.info > ul")[safe: 1]?
                    .text()) ?? ""
                additionalAttributes[.airDate] = airDate
                
                return Anime(
                    reconstructedAnimeLink,
                    additionalAttributes: additionalAttributes,
                    description: animeSynopsis,
                    on: NASourcePantsubase.knownServers,
                    episodes: episodeCollection
                )
            }
    }
}
