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

public extension MyAnimeList {
    func update(_ reference: ListingAnimeReference, newState: ListingAnimeTrackingState) {
        collectMutationTaskPoolGarbage()
        
        let status: String
        switch newState {
        case .toWatch: status = "plan_to_watch"
        case .watching: status = "watching"
        case .finished: status = "completed"
        }
        
        // Send mutation request
        let task = apiRequest(
                "/anime/\(reference.uniqueIdentifier)/my_list_status",
                body: [ "status": status ],
                method: .put
            ) .error {
                [weak self] in
                Log.error("[MyAnimeList] Failed to mutate: %@", $0)
                self?.collectMutationTaskPoolGarbage()
            } .finally {
                [weak self] _ in
                Log.info("[MyAnimeList] Mutation made")
                self?.collectMutationTaskPoolGarbage()
            }
        $_mutationTaskPool.mutate {
            $0.append(task)
        }
    }
    
    func update(_ reference: ListingAnimeReference, didComplete episode: EpisodeLink, episodeNumber: Int?, shouldUpdateTrackingState: Bool = true) {
        collectMutationTaskPoolGarbage()
        
        guard let episodeNumber = episodeNumber else {
            Log.info("[MyAnimeList] Not pushing states because episode number cannot be inferred.")
            return
        }
        
        // Obtain the new tracking and push
        let newTracking = progressTracking(
            for: reference,
            withUpdatedEpisodeProgress: episodeNumber
        )
        update(reference, newTracking: newTracking)
        
        if shouldUpdateTrackingState {
            let listingInfoTask = self.listingAnime(from: reference)
            .defer { _ in self.collectMutationTaskPoolGarbage() }
            .error {
                Log.error("[MyAnimeList] Failed To Retrieve Anime Listing Information with error: %@", $0)
            }
            .finally {
                [weak self] listingInfo in
                guard let self = self else { return }
                // If the anime has finished airing, and the user has completed the last episode, mark the anime as completed
                if let currentAiringStatus = listingInfo.information["Airing Status"],
                   currentAiringStatus == AiringStatus.finished.rawValue,
                   let totalNumOfEpisodes = newTracking.episodes,
                   totalNumOfEpisodes <= newTracking.currentProgress {
                    Log.info("[MyAnimeList] User has finished last episode of anime. Moving %@ to completed list.", reference.name)
                    self.update(reference, newState: .finished)
                }
            }
            $_mutationTaskPool.mutate {
                $0.append(listingInfoTask)
            }
        }
    }
    
    func collectMutationTaskPoolGarbage() {
        // Remove all resolved promises
        $_mutationTaskPool.mutate {
            $0.removeAll {
                ($0 as? NineAnimatorPromiseProtocol)?.isResolved == true
            }
        }
    }
    
    func update(_ reference: ListingAnimeReference, newTracking: ListingAnimeTracking) {
        collectMutationTaskPoolGarbage()
        
        // Send mutation request
        let task = apiRequest(
            "/anime/\(reference.uniqueIdentifier)/my_list_status",
            body: [ "num_watched_episodes": newTracking.currentProgress ],
            method: .put
            ) .error {
                [weak self] in
                Log.error("[MyAnimeList] Failed to mutate: %@", $0)
                self?.collectMutationTaskPoolGarbage()
            } .finally {
                [weak self] _ in
                guard let self = self else { return }
                Log.info("[MyAnimeList] Mutation made")
                self.collectMutationTaskPoolGarbage()
                self.donateTracking(newTracking, forReference: reference)
        }
        $_mutationTaskPool.mutate {
            $0.append(task)
        }
    }
    
    /// Construct the `ListingAnimeTracking` from the AnimeObject's `node` dictionary
    func constructTracking(fromAnimeNode node: NSDictionary) -> ListingAnimeTracking? {
        if let currentProgress = node.valueIfPresent(
            at: "my_list_status.num_episodes_watched",
            type: Int.self
        ) {
            return ListingAnimeTracking(
                currentProgress: currentProgress,
                episodes: node.valueIfPresent(at: "num_episodes", type: Int.self)
            )
        }
        return nil
    }
}
