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

extension NASourceTheWatchCartoonOnline {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        request(browseUrl: link.link).then {
            responseContent -> Anime in
            let bowl = try SwiftSoup.parse(responseContent)
            let animeTitle = try bowl.select("div.h1-tag a").text()
            let animeSynopsis = try bowl.select("div.eight.columns p").text()
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
            let episodes = try bowl.select("div.recent-release-main div.cat-eps").reduce(into: [EpisodeLink]()) {
                collection, container in
                let episodeName = try container.select("div.cat-eps").text()
                var episodeLink = try container.select("a").attr("href")
                episodeLink = episodeLink.replacingOccurrences(of: "'", with: "\'")
                if !episodeLink.isEmpty {
                collection.append(.init(
                    identifier: episodeLink,
                    name: episodeName,
                    server: NASourceTheWatchCartoonOnline.NASourceTheWatchCartoonOnlineStream,
                    parent: reconstructedAnimeLink
                ))
                }
            }
            
            // Information
            // Attributes
            return Anime(
                reconstructedAnimeLink,
                alias: animeTitle,
                description: animeSynopsis,
                on: [ NASourceTheWatchCartoonOnline.NASourceTheWatchCartoonOnlineStream: "TheWatchCartoonOnline" ],
                episodes: [ NASourceTheWatchCartoonOnline.NASourceTheWatchCartoonOnlineStream: episodes ],
                episodesAttributes: [:]
            )
        }
    }
}
