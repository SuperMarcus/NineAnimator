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
    
    func update(_ reference: ListingAnimeReference, didComplete episode: EpisodeLink) {
        // First, get the episode number
        let episodeNumber = suggestEpisodeNumber(from: episode.name)
        
        // Make GraphQL mutation request
        mutationGraphQL(fileQuery: "AniListTrackingMutation", variables: [
            "mediaId": Int(reference.uniqueIdentifier)!,
            "progress": episodeNumber
        ])
    }
}
