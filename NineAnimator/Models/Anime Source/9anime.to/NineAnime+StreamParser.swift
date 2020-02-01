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

extension NASourceNineAnime {
    func parseAvailableEpisodes(from responseJson: NSDictionary, with parent: AnimeLink) throws -> Anime.EpisodesCollection {
        guard let htmlList = responseJson["html"] as? String else {
            Log.error("Invalid response")
            throw NineAnimatorError.responseError("unable to retrieve episode list from responses")
        }
        
        let matches = NASourceNineAnime.animeServerListRegex.matches(
            in: htmlList, range: htmlList.matchingRange
        )
        
        let animeServers: [Anime.ServerIdentifier: String] = Dictionary(
            matches.map { match in
                (htmlList[match.range(at: 1)], htmlList[match.range(at: 2)])
            }
        ) { _, new in new }
        
        var animeEpisodes = Anime.EpisodesCollection()
        
        Log.debug("%@ servers found for this anime.", animeServers.count)
        
        let soup = try SwiftSoup.parse(htmlList)
        
        for server in try soup.select("div.server") {
            let serverIdentifier = try server.attr("data-id")
            animeEpisodes[serverIdentifier] = try server.select("li>a").map {
                let dataIdentifier = try $0.attr("data-id")
                let pathIdentifier = try $0.attr("href")
                return EpisodeLink(
                    identifier: try $0.attr("data-id"),
                    name: "\(dataIdentifier)|\(pathIdentifier)",
                    server: serverIdentifier,
                    parent: parent
                )
            }
            Log.debug("%@ episodes found on server %@", animeEpisodes[serverIdentifier]!.count, serverIdentifier)
        }
        
        return animeEpisodes
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        VideoProviderRegistry.default.provider(for: name)
    }
}
