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

// This Version of AnimeHub+Episode has extra checks to make sure
// that the user selected server is available. It also provides enhanced
// error messages (EpisodeServerNotAvailableError).
// However, since it makes multiple network requests, it is very slow.
// Therefore we are disabling it.

import Foundation
import SwiftSoup

extension NASourceAnimeHub {
    static let knownServers = [
        "fserver": "Fserver",
        "fdserver": "FDserver",
        //"xserver": "Xserver", Seems like this no episodes support this server
        "oserver": "Oserver",
        "mpserver": "MPserver",
        "yuserver": "YUserver",
        //"hserver": "Hserver" Excluding until we update HydraX parser
    ]

    static let urlRegex = try! NSRegularExpression(pattern: #"((([A-Za-z]{3,9}:(?:\/\/)?)(?:[-;:&=\+\$,\w]+@)?[A-Za-z0-9.-]+|(?:www.|[-;:&=\+\$,\w]+@)[A-Za-z0-9.-]+)((?:\/[\+~%\/.\w-_]*)?\??(?:[-\+=&;%@.\w_]*)#?(?:[\w]*))?)"#, options: .caseInsensitive)
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        self.requestManager.request(
            link.identifier,
            handling: .browsing
        ).responseString.thenPromise {
            responseContent in
            let bowl = try SwiftSoup.parse(responseContent)
            
            // Get available servers
            let availableServerList = try bowl.select("#selectServer > option").map {
                serverContainer in
                try serverContainer.attr("sv")
            } .filter {
                // Exclude any servers that NineAnimator does not support
                NASourceAnimeHub.knownServers.keys.contains($0)
            }
            
            // Check if selected server is available
            guard availableServerList.contains(link.server) else {
                let alternativeEpisodeLinks = availableServerList.map {
                    alternativeServer in EpisodeLink(
                        identifier: link.identifier,
                        name: link.name,
                        server: alternativeServer,
                        parent: link.parent
                    )
                }
                // Throw EpisodeServerNotAvailableError with the list of alternatives
                throw NineAnimatorError.EpisodeServerNotAvailableError(
                    unavailableEpisode: link,
                    alternativeEpisodes: alternativeEpisodeLinks,
                    updatedServerMap: NASourceAnimeHub.knownServers
                )
            }
            
            // Extract Episode ID from EpisodeLink URL
            let episodeURLParams = try URL(string:link.identifier, relativeTo: self.endpointURL).tryUnwrap()
                .query
                .tryUnwrap()
            let episodeID = try formDecode(episodeURLParams).value(at: "ep", type: String.self)
            
            // Request api for episode iframe (if available)
            return self.requestManager.request(
                "ajax/anime/load_episodes_v2",
                handling: .ajax,
                query: ["s": link.server],
                parameters: ["episode_id": episodeID]
            ).responseData.then {
                responseContent in
                // Convert response into NSDictionary
                let responseJSON = try JSONSerialization.jsonObject(with: responseContent, options: []) as! NSDictionary
                
                let iframe = try responseJSON.value(at: "value", type: String.self)
                
                // Extract URL from iframe
                var iframeURLString = try (NASourceAnimeHub.urlRegex.firstMatch(in: iframe)?
                    .firstMatchingGroup)
                    .tryUnwrap()
                
                // Add URL scheme if not present
                if !iframeURLString.hasPrefix("https://") {
                    iframeURLString = "https://\(iframeURLString)"
                }
                
                let iframeURL = try URL(string: iframeURLString).tryUnwrap()
                
                return Episode(
                    link,
                    target: iframeURL,
                    parent: anime
                )
            }
        }
    }
}
