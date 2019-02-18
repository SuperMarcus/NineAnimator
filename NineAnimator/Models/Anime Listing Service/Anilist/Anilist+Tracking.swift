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

private let _queryMutateMediaState = "mutation ( $id: Int, $mediaId: Int, $status: MediaListStatus, $score: Float, $progress: Int, $progressVolumes: Int, $repeat: Int, $private: Boolean, $notes: String, $customLists: [String], $hiddenFromStatusLists: Boolean, $advancedScores: [Float], $startedAt: FuzzyDateInput, $completedAt: FuzzyDateInput ) { SaveMediaListEntry ( id: $id, mediaId: $mediaId, status: $status, score: $score, progress: $progress, progressVolumes: $progressVolumes, repeat: $repeat, private: $private, notes: $notes, customLists: $customLists, hiddenFromStatusLists: $hiddenFromStatusLists, advancedScores: $advancedScores, startedAt: $startedAt, completedAt: $completedAt ) { id mediaId status score progress progressVolumes repeat priority private hiddenFromStatusLists customLists notes updatedAt startedAt { year month day } completedAt { year month day } user { id name } media { id title { userPreferred } coverImage { large } type format status episodes volumes chapters averageScore popularity isAdult startDate { year } } } }"

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
        mutationGraphQL(query: _queryMutateMediaState, variables: [
            "mediaId": Int(reference.uniqueIdentifier)!,
            "status": state
        ])
        
        // Invalidate collection caches
        _collections = nil
    }
    
    func update(_ reference: ListingAnimeReference, didComplete episode: EpisodeLink) {
        // First, get the episode number
        guard let nameFirstPortion = episode.name.split(separator: " ").first,
            let episodeNumber = Int(String(nameFirstPortion)) else {
            Log.info("Cannot update episode with name \"%\": the name does not suggest an episode number", episode.name)
                return
        }
        
        // Make GraphQL mutation request
        mutationGraphQL(query: _queryMutateMediaState, variables: [
            "mediaId": Int(reference.uniqueIdentifier)!,
            "progress": episodeNumber
        ])
    }
}
