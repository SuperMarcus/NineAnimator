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

extension Kitsu {
    func update(_ reference: ListingAnimeReference, newState: ListingAnimeTrackingState) {
        // Cleanup any previous completed mutation request
        collectMutationTaskPoolGarbage()
        
        let libraryEntryState: String
        switch newState {
        case .finished: libraryEntryState = "completed"
        case .toWatch: libraryEntryState = "planned"
        case .watching: libraryEntryState = "current"
        }
        
        // Make the request
        let task = currentUser().thenPromise {
            [unowned self] user in
            self.apiRequest(
                "/library-entries",
                body: [
                    "data": [
                        "attributes": [ "status": libraryEntryState ],
                        "relationships": [
                            "anime": [
                                "data": [
                                    "type": "anime",
                                    "id": reference.uniqueIdentifier
                                ]
                            ],
                            "user": [
                                "data": [
                                    "type": "users",
                                    "id": user.identifier
                                ]
                            ]
                        ],
                        "type": "library-entries"
                    ]
                ],
                method: .post
            )
        } .error {
            Log.error("[Kitsu.io] Failed to mutate: %@", $0)
        } .finally { _ in Log.info("[Kitsu.io] Mutation made") }
        
        // Save the reference in the task pool
        _mutationTaskPool.append(task)
    }
    
    func update(_ reference: ListingAnimeReference, didComplete episode: EpisodeLink) {
        collectMutationTaskPoolGarbage()
        
        // First, get the episode number
        var episodeNumber = 1 // Default to episode 1
        if let nameFirstPortion = episode.name.split(separator: " ").first {
            episodeNumber = Int(String(nameFirstPortion)) ?? 1
            Log.info("[Kitsu.io] Episode name \"%\" does not suggest an episode number. Using 1 as the progress.", episode.name)
            return
        }
        
        // Make the request
        let task = currentUser().thenPromise {
            [unowned self] user in self.libraryEntry(for: reference).then { (user, $0) }
        } .thenPromise {
            [unowned self] (user: User, entry: LibraryEntry) in
            self.apiRequest(
                "/library-entries/\(entry.identifier)",
                body: [
                    "data": [
                        "id": entry.identifier,
                        "attributes": [ "progress": episodeNumber ],
                        "relationships": [
                            "anime": [
                                "data": [
                                    "type": "anime",
                                    "id": reference.uniqueIdentifier
                                ]
                            ],
                            "user": [
                                "data": [
                                    "type": "users",
                                    "id": user.identifier
                                ]
                            ],
                            "mediaReaction": [ "data": nil ]
                        ],
                        "type": "library-entries"
                    ]
                ],
                method: .patch
            )
        } .error {
            Log.error("[Kitsu.io] Failed to mutate: %@", $0)
        } .finally { _ in Log.info("[Kitsu.io] Mutation made") }
        
        // Save the reference in the task pool
        _mutationTaskPool.append(task)
    }
    
    private func collectMutationTaskPoolGarbage() {
        // Remove all resolved promises
        _mutationTaskPool.removeAll { ($0 as? NineAnimatorPromiseProtocol)?.isResolved == true }
    }
}
