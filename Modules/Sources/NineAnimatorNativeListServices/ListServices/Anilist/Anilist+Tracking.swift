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

public extension Anilist {
    func update(_ reference: ListingAnimeReference, newState: ListingAnimeTrackingState) {
        // Convert NineAnimator state to Anilist state enum
        let state: String
        switch newState {
        case .finished: state = "COMPLETED"
        case .toWatch: state = "PLANNING"
        case .watching: state = "CURRENT"
        }
        
        // Making a mutational GraphQL request
        mutationGraphQL(fileQuery: "AniListTrackingMutation", variables: [
            "mediaId": Int(reference.uniqueIdentifier)!,
            "status": state
        ])
        
        // Invalidate collection caches
        _collections = nil
    }
    
    func update(_ reference: ListingAnimeReference, didComplete episode: EpisodeLink, episodeNumber: Int?, shouldUpdateTrackingState: Bool = true) {
        // First, get the episode number
        guard let episodeNumber = episodeNumber else {
            Log.info("[AniList.co] Not pushing states because episode number cannot be inferred.")
            return
        }
        
        // Obtain the new tracking
        let updatedTracking = progressTracking(
            for: reference,
            withUpdatedEpisodeProgress: episodeNumber
        )
        // Update the Episode Progress
        update(reference, newTracking: updatedTracking)
        
        if shouldUpdateTrackingState {
            // Retrieve detailed anime information to determine if tracking state needs updating
            let listingInfoTask = self.listingAnime(from: reference)
            .defer { _ in self.cleanupReferencePool() }
            .error {
                Log.error("[AniList.co] Failed To Retrieve Anime Listing Information with error: %@", $0)
            }
            .finally {
                [weak self] listingInfo in
                guard let self = self else { return }
                // If the anime has finished airing, and the user has completed the last episode, mark the anime as completed
                if let currentAiringStatus = listingInfo.information["Airing Status"],
                   currentAiringStatus == AiringStatus.finished.rawValue,
                   let totalNumOfEpisodes = updatedTracking.episodes,
                   totalNumOfEpisodes <= updatedTracking.currentProgress {
                    Log.info("[AniList.co] User has finished last episode of anime. Moving %@ to completed list.", reference.name)
                    self.update(reference, newState: .finished)
                }
            }
            $_mutationRequestReferencePool.mutate {
                $0.append(listingInfoTask)
            }
        }
    }
    
    func update(_ reference: ListingAnimeReference, newTracking: ListingAnimeTracking) {
        // Make GraphQL mutation request and save the new tracking state if
        // succeeded.
        // swiftlint:disable multiline_arguments
        mutationGraphQL(fileQuery: "AniListTrackingMutation", variables: [
            "mediaId": Int(reference.uniqueIdentifier)!,
            "progress": newTracking.currentProgress
        ]) { if $0 { self.donateTracking(newTracking, forReference: reference) } }
        // swiftlint:enable multiline_arguments
    }
    
    /// Update a tracking state for a particular reference
    ///
    /// Sources of `ListingAnimeTracking`:
    /// - `init` of `StaticListingAnimeCollection`
    /// - `Anilist.reference(from: AnimeLink)`
    func contributeReferenceTracking(_ tracking: ListingAnimeTracking, forReference reference: ListingAnimeReference) {
        donateTracking(tracking, forReference: reference)
    }
    
    /// Create the `ListingAnimeTracking` from query results
    internal func createReferenceTracking(from mediaList: GQLMediaList?, withSupplementalMedia media: GQLMedia) -> ListingAnimeTracking? {
        // Supposingly it's only valid for a currently watching anime
        if /* mediaList?.status == .current, */let progress = mediaList?.progress {
            return ListingAnimeTracking(
                currentProgress: progress,
                episodes: media.episodes
            )
        } else { return nil }
    }
}
