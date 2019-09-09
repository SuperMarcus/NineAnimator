//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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

extension Simkl {
    func update(_ reference: ListingAnimeReference, newState: ListingAnimeTrackingState) {
        do {
            let updateTask = apiRequest(
                "/sync/add-to-list",
                body: try JSONSerialization.data(
                    withJSONObject: [
                        "shows": [
                            [
                                "title": reference.name,
                                "to": self.stateToSimkl(newState),
                                "ids": [ "simkl": reference.uniqueIdentifier ]
                            ]
                        ]
                    ],
                    options: []
                ),
                method: .post,
                expectedResponseType: [String: Any].self
            ) .error {
                error in Log.error(
                    "[Simkl.com] Unable to update state for reference %@ because a communication problem: %@",
                    reference.name,
                    error
                )
            } .finally {
                _ in Log.info("[Simkl.com] Mutation request completed")
            }
            mutationQueues.append(updateTask)
        } catch {
            Log.error("[Simkl.com] Unable to update state for reference %@: %@", reference.name, error)
        }
    }
    
    func update(_ reference: ListingAnimeReference, didComplete episode: EpisodeLink, episodeNumber: Int?) { }
}
