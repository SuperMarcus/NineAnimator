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

extension Kitsu {
    func reference(from link: AnimeLink) -> NineAnimatorPromise<ListingAnimeReference> {
        apiRequest("/anime", query: [
            "fields[anime]": "canonicalTitle,posterImage,titles",
            "filter[text]": link.title,
            "page[offset]": "0",
            "page[limit]": "20" // Looking for the first 20 anime entries to match
        ]) .then {
            [unowned self] matchedObjects -> ListingAnimeReference in
            let bestMatchOptional = try matchedObjects.map {
                match -> (Double, ListingAnimeReference) in
                let titles = (match.attributes["titles"] as? [String: String]) ?? [:]
                let proximity = titles.reduce(0.0) { max($0, $1.value.proximity(to: link.title)) }
                return (proximity, try ListingAnimeReference(self, withAnimeObject: match))
            } .max { $0.0 < $1.0 }
            guard let bestMatch = bestMatchOptional else {
                throw NineAnimatorError.responseError("No matching reference found")
            }
            guard bestMatch.0 > 0.8 else {
                throw NineAnimatorError.responseError("Failed to make a confident match: maximal proximity is only \(bestMatch.0)")
            }
            return bestMatch.1
        } .thenPromise { // Fetch library entry state
            [unowned self] matchedReference in
            NineAnimatorPromise {
                [unowned self] callback in
                if self.didSetup && !self.didExpire {
                    // Look for the reference in the library entry
                    return self.libraryEntry(for: matchedReference).error {
                        _ in callback(matchedReference, nil) // If errored (or DNE), return the original reference
                    } .finally { entry in callback(matchedReference.with(libraryEntry: entry), nil) }
                } else { callback(matchedReference, nil) }
                return nil
            }
        }
    }
}
