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

extension NASourceHentaiWorld {
    private static let regex = try! NSRegularExpression(
        pattern: "[0-9]{2} [A-Za-z]* [0-9]{4}"
    )
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager
            .request(url: link.link, handling: .browsing)
            .responseString
            .then {
                responseContent -> Anime in
                let bowl = try SwiftSoup.parse(responseContent)
                let animeTitle = try bowl.select("div.widget-title h1").attr("data-jtitle")
                let engTitle = try? bowl.select("div.widget-title h1").text()
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
                let episodes = try bowl.select("div.active ul li").reduce(into: [EpisodeLink]()) {
                    collection, container in
                    let name =  try container.select("a").text()
                    let episodeName = name
                    var episodeLink = try container.select("a").attr("href")
                    episodeLink = episodeLink.replacingOccurrences(of: "'", with: "\'")
                    if !episodeLink.isEmpty {
                        collection.append(.init(
                            identifier: self.endpoint + (episodeLink),
                            name: episodeName,
                            server: NASourceHentaiWorld.HentaiWorldStream,
                            parent: reconstructedAnimeLink
                            ))
                    }
                }
                
                // Information
                let animeSynopsis = try bowl.select("div.info div.desc").text()
                // Attributes
                let additionalAttributes = try bowl.select("div.row div.info div.row dd").reduce(into: [Anime.AttributeKey: Any]()) { attributes, entry in
                    let info = try entry.html()
                    let results = NASourceHentaiWorld.regex.matches(in: info)
                    if !results.isEmpty {
                        attributes[.airDate] = info
                    }
                    if entry.debugDescription.contains("rating") {
                        let rate = try entry.select("dd span").text()
                        attributes[.rating] = (rate as NSString).floatValue
                        attributes[.ratingScale] = Float(10.0)
                    }
                }
                return Anime(
                    reconstructedAnimeLink,
                    alias: engTitle ?? animeTitle,
                    additionalAttributes: additionalAttributes,
                    description: animeSynopsis,
                    on: [ NASourceHentaiWorld.HentaiWorldStream: "HentaiWorld" ],
                    episodes: [ NASourceHentaiWorld.HentaiWorldStream: episodes ],
                    episodesAttributes: [:]
                )
            }
    }
}
