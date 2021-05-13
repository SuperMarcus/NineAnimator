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

extension NASourceAnimeHub {
    static let knownServers = [
        "fserver": "Fserver",
        "fdserver": "FDserver",
        // "xserver": "Xserver", Seems like this no episodes support this server
        "oserver": "Oserver",
        "mserver": "Mserver",
        "yuserver": "YUserver"
        // "hserver": "Hserver" Excluding until we update HydraX parser
    ]
    /// Represents the response from AnimeHub episode endpoint
    fileprivate struct EpisodeResponse: Decodable {
        let status: Bool
        let value: String
        let embed: Bool
        let html5: Bool
        let type: String
        let sv: String
        let download_get: String
    }

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
                method: .post,
                query: ["s": link.server],
                parameters: ["episode_id": episodeID],
                headers: [ "referer": anime.link.link.absoluteString ]
                ).responseDecodable(type: EpisodeResponse.self)
        } .then {
            episodeResponse in
            // Check if server is available.
            // Note: The api might incorrectly state that the server is available.
            guard episodeResponse.status == true else {
                throw NineAnimatorError
                    .EpisodeServerNotAvailableError(unavailableEpisode: link)
            }
            
            // Extract URL from iframe
            var iframeURLString = try (NASourceAnimeHub.urlRegex.firstMatch(in: episodeResponse.value)?
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
