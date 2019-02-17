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

private let _queryMediaWithName =
"""
query ($search: String, $seasonYear: Int) {
  Media (
    search: $search
    type: ANIME
    seasonYear: $seasonYear
    sort: [TITLE_ENGLISH, TITLE_ROMAJI, TITLE_NATIVE]
  ) {
    id
    coverImage { extraLarge }
    title { userPreferred }
    mediaListEntry { status }
  }
}
"""

extension Anilist {
    func reference(from link: AnimeLink) -> NineAnimatorPromise<ListingAnimeReference> {
        return graphQL(query: _queryMediaWithName, variables: [
            "search": link.title
        ]) .then {
            responseDictionary in
            guard let mediaEntry = responseDictionary["Media"] as? NSDictionary else {
                throw NineAnimatorError.responseError("Media entry not found")
            }
            return try ListingAnimeReference(self, withMediaEntry: mediaEntry)
        }
    }
}
