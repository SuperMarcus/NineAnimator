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

extension NASourceGogoAnime {
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        let urlComponents = url.pathComponents
        switch urlComponents.count {
        case 3 where urlComponents[1] == "category":
            Log.info("Identified the link as an anime link")
            return anime(url: url).then { .anime($0.link) }
        case 2:
            Log.info("Identified the link as an episode link")
            let episodeIdentifierComponent = "/\(urlComponents[1])"
            
            // Retrieve anime identifier from episode identifier
            guard let animeIdentifier =
                NASourceGogoAnime.animeLinkFromEpisodePathRegex
                    .firstMatch(in: episodeIdentifierComponent)?
                    .firstMatchingGroup else {
                return .fail(.urlError)
            }
            
            // Assemble anime url
            guard let animeUrl = URL(string: "\(self.endpoint)/category/\(animeIdentifier)") else {
                return .fail(.urlError)
            }
            
            return anime(url: animeUrl).then {
                anime in
                let episodePool: [EpisodeLink]
                
                // Determine a server
                if let server = NineAnimator.default.user.recentServer,
                    let pool = anime.episodes[server] {
                    episodePool = pool
                } else if let pool = anime.episodes.first?.value {
                    episodePool = pool
                } else { throw NineAnimatorError.responseError("No episodes available on this link") }
                
                // Find the episode link with the same identifier
                if let episode = episodePool.first(where: { $0.identifier == episodeIdentifierComponent }) {
                    return .episode(episode)
                }
                
                // If no episode with the same identifier is found
                throw NineAnimatorError.responseError("Did not find this episode in this anime")
            }
        default: return .fail(.urlError)
        }
    }
}
