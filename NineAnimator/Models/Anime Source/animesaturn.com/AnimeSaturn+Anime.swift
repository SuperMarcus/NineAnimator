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

extension NASourceAnimeSaturn {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager
            .request(url: link.link, handling: .browsing)
            .responseString
            .then {
                responseContent -> Anime in
                let bowl = try SwiftSoup.parse(responseContent)
                let animeTitle = try bowl.select("div.container.anime-title-as.mb-3.w-100 b").text()
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
                let episodes = try bowl.select("div.tab-content div div.episodes-button").reduce(into: [EpisodeLink]()) {
                    collection, container in
                    let name =  try container.select("a").text().components(separatedBy: " ")
                    let episodeName = name[1]
                    var episodeLink = try container.select("a").attr("href")
                    episodeLink = episodeLink.replacingOccurrences(of: "'", with: "\'")
                    if !episodeLink.isEmpty {
                        collection.append(.init(
                            identifier: episodeLink,
                            name: episodeName,
                            server: NASourceAnimeSaturn.AnimeSaturnStream,
                            parent: reconstructedAnimeLink
                            ))
                    }
                }
                
                // Information
                let alias = try bowl.select("div.box-trasparente-alternativo.rounded").first()?.text()
                let animeSynopsis = try bowl.select("#shown-trama").text()
                //var additionalAttributes = [Anime.AttributeKey: Any]()
                // Attributes
                let additionalAttributes = try bowl.select("div.container.shadow.rounded.bg-dark-as-box.mb-3.p-3.w-100.text-white").reduce(into: [Anime.AttributeKey: Any]()) { attributes, entry in
                    let info = try entry.html().components(separatedBy: "<br>")
                    for elem in info {
                        if elem.contains("<b>Voto:</b> ") {
                            var rat = elem.components(separatedBy: "<b>Voto:</b> ")
                            rat = rat[safe: 1]?.components(separatedBy: "/") ?? []
                            let rating = ((rat[safe: 0] ?? "") as NSString).floatValue
                            attributes[.rating] = rating
                            attributes[.ratingScale] = Float(5.0)
                        }
                        if elem.contains("<b>Data di uscita:</b> ") {
                            let rat = elem.components(separatedBy: "<b>Data di uscita:</b> ")
                            let airdate = rat[1]
                            attributes[.airDate] = airdate
                        }
                    }
                }
                return Anime(
                    reconstructedAnimeLink,
                    alias: alias ?? animeTitle,
                    additionalAttributes: additionalAttributes,
                    description: animeSynopsis,
                    on: [ NASourceAnimeSaturn.AnimeSaturnStream: "AnimeSaturn" ],
                    episodes: [ NASourceAnimeSaturn.AnimeSaturnStream: episodes ],
                    episodesAttributes: [:]
                )
            }
    }
}
