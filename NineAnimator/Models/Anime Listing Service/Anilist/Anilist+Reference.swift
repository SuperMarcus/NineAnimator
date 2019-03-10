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
    func reference(from link: AnimeLink) -> NineAnimatorPromise<ListingAnimeReference> {
        func nameProximity(_ mediaEntry: NSDictionary) -> Double {
            guard let titleEntry = mediaEntry["title"] as? NSDictionary else { return 0 }
            return titleEntry
                .allValues
                .compactMap { $0 as? String }
                .reduce(0.0) { max($0, $1.proximity(to: link.title)) }
        }
        
        return graphQL(fileQuery: "AniListSearchReference", variables: [
            "search": link.title
        ]) .then {
            responseDictionary in
            guard let mediaEntries = responseDictionary.value(forKeyPath: "Page.media") as? [NSDictionary] else {
                throw NineAnimatorError.responseError("Media entry not found")
            }
            let results = try mediaEntries
                .map {
                    (
                        try ListingAnimeReference(self, withMediaEntry: $0),
                        nameProximity($0)
                    )
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
