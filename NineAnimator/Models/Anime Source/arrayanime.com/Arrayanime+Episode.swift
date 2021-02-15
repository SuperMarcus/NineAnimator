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

import Alamofire
import Foundation

extension NASourceArrayanime {
    static let knownServers = [
        "gstore": "Google Video",
        "cloud9": "Cloud9"
    ]
    
    fileprivate struct EpisodeResponse: Decodable {
        let links: [EpisodeLinks]
        let link: String? // Ignoring this link
        let totalepisode: String
    }
    
    fileprivate struct EpisodeLinks: Decodable {
        let link: String
        let name: String
    }
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise<String>.firstly {
            // Extract Anime ID From URL
            let animeID = anime.link.link.lastPathComponent
            guard !animeID.isEmpty else { throw NineAnimatorError.urlError }
            return animeID
        }.thenPromise {
            animeID -> NineAnimatorPromise<EpisodeResponse> in
            self.requestManager.request(
                url: self.vercelEndpoint.absoluteString + "/watching/\(animeID)/\(link.name)",
                handling: .default
            ) .responseDecodable(type: EpisodeResponse.self)
        }.then {
            episodeResponse -> Episode in
            
            // Sever Selection
            var episodeSource: String = ""
            episodeResponse.links.forEach { episodeLink in
                if link.server == "gstore" && episodeLink.name.contains("HDP") {
                    episodeSource = episodeLink.link
                } else if link.server == "cloud9" && episodeLink.name.contains("1080P") {
                    episodeSource = episodeLink.link
                }
            }

            let episodeURL = try URL(string: episodeSource).tryUnwrap(.urlError)
            
            return Episode(
                link,
                target: episodeURL,
                parent: anime
            )
        }
    }
}
