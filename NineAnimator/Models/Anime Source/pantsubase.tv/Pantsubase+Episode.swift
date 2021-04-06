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

extension NASourcePantsubase {
    static let knownServers = [
        "pantsudrive": "Pantsudrive" // These names lol
    ]
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        requestManager.request(url: link.identifier)
            .responseBowl
            .then {
                bowl in
                // Currently only supporting pantsudrive server
                guard link.server == "pantsudrive" else {
                    throw NineAnimatorError.unknownError("Unknown selected server")
                }
                
                let iFrameURL = try URL(string: bowl
                    .select("#iframe-to-load")
                    .attr("src"))
                    .tryUnwrap()
                    
                return Episode(
                    link,
                    target: iFrameURL,
                    parent: anime
                )
            }
    }
}
