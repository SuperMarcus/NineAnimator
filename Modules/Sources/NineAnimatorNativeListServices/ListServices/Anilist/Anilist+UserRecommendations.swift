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
    class AnilistUserRecommendations: RecommendationSource {
        public var shouldPresentRecommendation: Bool { parent.didSetup }
        
        public var name: String = "Anime For You"
        
        public var priority: Priority = .defaultLow
        
        private let parent: Anilist
        
        public init(_ parent: Anilist) {
            self.parent = parent
        }
        
        public func shouldReload(recommendation: Recommendation) -> Bool {
            false
        }
        
        public func generateRecommendations() -> NineAnimatorPromise<Recommendation> {
            parent.graphQL(fileQuery: "AnilistUserRecommendations", variables: [
                "page": 0,
                "perPage": 50
            ]) .then {
                responseDictionary in
                
                let recommendations = try DictionaryDecoder().decode(
                    GQLUserRecommendations.self,
                    from: try responseDictionary.value(at: "Page", type: NSDictionary.self)
                )
                
                let listingReferences = try recommendations.recommendations
                    .tryUnwrap()
                    .map {
                    item in
                        try ListingAnimeReference(
                            self.parent,
                            withMediaObject: item.mediaRecommendation.tryUnwrap()
                        )
                }
                let recommendingItems = listingReferences.map {
                    RecommendingItem(.listingReference($0))
                }
                return Recommendation(
                    self,
                    items: recommendingItems,
                    title: "Anime For You",
                    subtitle: "Anilist"
                )
            }
        }
    }
}
