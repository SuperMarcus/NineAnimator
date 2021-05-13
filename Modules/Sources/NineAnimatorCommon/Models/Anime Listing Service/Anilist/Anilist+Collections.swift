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

public extension Anilist {
    func collections() -> NineAnimatorPromise<[ListingAnimeCollection]> {
        // If cached collections does exists
        if let cachedCollections = _collections {
            return NineAnimatorPromise.firstly { cachedCollections }
        }
        
        return currentUser().thenPromise {
            [unowned self] user -> NineAnimatorPromise<(NSDictionary, User)> in
            self.graphQL(fileQuery: "AniListUserMediaCollections", variables: [
                "userId": user.id,
                "usernName": user.name
            ]).then { ($0, user) }
        } .then {
            [unowned self] responseDictionary, user in
            let collections = try DictionaryDecoder().decode(
                GQLMediaListCollection.self,
                from: try responseDictionary.value(
                    at: "MediaListCollection",
                    type: NSDictionary.self
                )
            )
            let mappedCollections = try collections.lists?.map {
                try StaticListingAnimeCollection(self, withCollectionObject: $0)
            }
            
            // List the collections in the user's preferred order
            if let mediaListSortingOrder = user.mediaListOptions.animeList?.sectionOrder,
                let mappedCollections = mappedCollections {
                return mappedCollections.map {
                    (mediaListSortingOrder.firstIndex(of: $0.title) ?? 100, $0)
                } .sorted {
                    $0.0 < $1.0
                } .map { $1 }
            }
            
            return mappedCollections
        }
    }
}
