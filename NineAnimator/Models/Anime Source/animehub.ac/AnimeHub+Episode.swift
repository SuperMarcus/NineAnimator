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
    static let knownServers = [
        "fserver": "Fserver",
        "fdserver": "FDserver",
        //"xserver": "Xserver", Seems like this no episodes support this server
        "oserver": "Oserver",
        "mpserver": "MPserver",
        "yuserver": "YUserver"
        //"hserver": "Hserver" Excluding until we update HydraX parser
    ]

    static let urlRegex = try! NSRegularExpression(pattern: #"((([A-Za-z]{3,9}:(?:\/\/)?)(?:[-;:&=\+\$,\w]+@)?[A-Za-z0-9.-]+|(?:www.|[-;:&=\+\$,\w]+@)[A-Za-z0-9.-]+)((?:\/[\+~%\/.\w-_]*)?\??(?:[-\+=&;%@.\w_]*)#?(?:[\w]*))?)"#, options: .caseInsensitive)
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise<String>.firstly {
            // Extract Episode ID from EpisodeLink URL
            let episodeURLParams = try URL(string: link.identifier, relativeTo: self.endpointURL).tryUnwrap()
                .query
                .tryUnwrap()
            let episodeID = try formDecode(episodeURLParams).value(at: "ep", type: String.self)
            return episodeID
        } .thenPromise {
            episodeID in
            // Request api for episode iframe
            self.requestManager.request(
                "ajax/anime/load_episodes_v2",
                handling: .ajax,
                query: ["s": link.server],
                parameters: ["episode_id": episodeID]
            ).responseData.then {
                responseContent in
                // Convert response into NSDictionary
                let responseJSON = try JSONSerialization.jsonObject(with: responseContent, options: []) as! NSDictionary
                
                // Check if server is available.
                // Note: The api might incorrectly state that the server is available.
                guard try responseJSON.value(at: "status", type: Int.self) == 1 else {
                    throw NineAnimatorError
                        .EpisodeServerNotAvailableError(unavailableEpisode: link)
                }

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
