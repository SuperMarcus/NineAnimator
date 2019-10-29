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

extension Anilist {
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
    
    func update(_ reference: ListingAnimeReference, didComplete episode: EpisodeLink, episodeNumber: Int?) {
        // First, get the episode number
        guard let episodeNumber = episodeNumber else {
            Log.info("[AniList.co] Not pushing states because episode number cannot be inferred.")
            return
        }
        
        var updatedTracking = progressTracking(for: reference) ?? ListingAnimeTracking(
            currentProgress: episodeNumber,
            episdoes: nil
        )
        updatedTracking.currentProgress = episodeNumber
        update(reference, newTracking: updatedTracking)
    }
    
    func progressTracking(for reference: ListingAnimeReference) -> ListingAnimeTracking? {
        return _mediaTrackingMap[reference]
    }
    
    func update(_ reference: ListingAnimeReference, newTracking: ListingAnimeTracking) {
        // Make GraphQL mutation request
        mutationGraphQL(fileQuery: "AniListTrackingMutation", variables: [
            "mediaId": Int(reference.uniqueIdentifier)!,
            "progress": newTracking.currentProgress
        ])
    }
    
    /// Update a tracking state for a particular reference
    ///
    /// Sources of `ListingAnimeTracking`:
    /// - `init` of `StaticListingAnimeCollection`
    /// - `Anilist.reference(from: AnimeLink)`
    func contributeReferenceTracking(_ tracking: ListingAnimeTracking, forReference reference: ListingAnimeReference) {
        var newTracking = tracking
        if let existingTracking = _mediaTrackingMap[reference] {
            newTracking.episdoes = newTracking.episdoes ?? existingTracking.episdoes
        }
        _mediaTrackingMap[reference] = newTracking
    }
    
    /// Create the `ListingAnimeTracking` from query results
    func createReferenceTracking(from mediaList: GQLMediaList?, withSupplementalMedia media: GQLMedia) -> ListingAnimeTracking? {
        // Supposingly it's only valid for a currently watching anime
        if /* mediaList?.status == .current, */let progress = mediaList?.progress {
            return ListingAnimeTracking(
                currentProgress: progress,
                episdoes: media.episodes
            )
        } else { return nil }
    }
}
