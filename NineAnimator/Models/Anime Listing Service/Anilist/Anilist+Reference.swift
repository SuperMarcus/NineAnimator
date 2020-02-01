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

extension Anilist {
    func reference(from link: AnimeLink) -> NineAnimatorPromise<ListingAnimeReference> {
        func nameProximity(_ mediaEntry: GQLMedia) -> Double {
            let titles = mediaEntry.title
            return [titles?.english, titles?.native, titles?.romaji, titles?.userPreferred]
                .compactMap { $0 }
                .reduce(0.0) { max($0, $1.proximity(to: link.title)) }
        }
        
        return graphQL(fileQuery: "AniListSearchReference", variables: [
            "search": link.title
        ]) .then {
            responseDictionary in
            let decodedMediaObjects = try responseDictionary.value(
                at: "Page.media",
                type: [NSDictionary].self
            ) .map { try DictionaryDecoder().decode(GQLMedia.self, from: $0) }
            let results = try decodedMediaObjects.map {
                mediaObject -> (ListingAnimeReference, Double) in
                let reference = try ListingAnimeReference(self, withMediaObject: mediaObject)
                
                // Obtain and contribute tracking
                if let tracking = self.createReferenceTracking(from: mediaObject.mediaListEntry, withSupplementalMedia: mediaObject) {
                    self.contributeReferenceTracking(tracking, forReference: reference)
                }
                
                return (reference, nameProximity(mediaObject))
            } .sorted { $0.1 > $1.1 }
            guard let bestMatch = results.first else {
                throw NineAnimatorError.responseError("No results found")
            }
            guard bestMatch.1 > 0.8 else {
                throw NineAnimatorError.responseError("Failed to make a confident match: maximal proximity is only \(bestMatch.1)")
            }
            return bestMatch.0
        }
    }
}
