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

public extension Simkl {
    func reference(from link: AnimeLink) -> NineAnimatorPromise<ListingAnimeReference> {
        apiRequest(
            "/search/anime",
            query: [
                "q": link.title,
                "page": 1,
                "limit": 20,
                "extended": "full",
                "client_id": clientId,
                "type": "anime"
            ],
            expectedResponseType: [[String: Any]].self
        ) .then {
            response -> SimklMediaEntry? in
            let possibleEntries = try response.map {
                try DictionaryDecoder().decode(SimklMediaEntry.self, from: $0)
            } .map { entry in (entry.title.proximity(to: link.title, caseSensitive: false), entry) }
            var returningItem = possibleEntries.first?.1
            
            if let maximalProximityItem = possibleEntries.max(by: { $0.0 < $1.0 }),
                maximalProximityItem.0 > 0.8 {
                returningItem = maximalProximityItem.1
                Log.info("[Simkl.com] A match with proximity %@ was found", maximalProximityItem.0)
            } else {
                Log.info("[Simkl.com] Unable to find a match for the item (all items have proximity values below threshold).")
            }
            
            return returningItem
        } .then {
            entry in ListingAnimeReference(
                self,
                name: entry.title,
                identifier: String(entry.ids.simkl_id),
                artwork: try self.artworkUrl(fromPosterPath: entry.poster)
            )
        }
    }
}
    
extension Simkl {
    func episodeObjects(forReference reference: ListingAnimeReference) -> NineAnimatorPromise<[SimklEpisodeEntry]> {
        if let cachedEntries = cachedReferenceEpisodes[reference.uniqueIdentifier] {
            return .success(cachedEntries)
        }
        
        return apiRequest(
            "/anime/episodes/\(reference.uniqueIdentifier)",
            expectedResponseType: [[String: Any]].self
        ) .then {
            let decoder = DictionaryDecoder()
            return try $0.map {
                try decoder.decode(SimklEpisodeEntry.self, from: $0)
            }
        } .then {
            (episodes: [SimklEpisodeEntry]) in
            self.cachedReferenceEpisodes[reference.uniqueIdentifier] = episodes
            return episodes
        }
    }
}
