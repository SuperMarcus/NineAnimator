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
    class AnilistUserRecommendations: RecommendationSource {
        var name: String = "Anime For You"
        
        var piority: Piority = .defaultLow
        
        private let parent: Anilist
        
        init(_ parent: Anilist) {
            self.parent = parent
        }
        
        func shouldReload(recommendation: Recommendation) -> Bool {
            false
        }
        
        func generateRecommendations() -> NineAnimatorPromise<Recommendation> {
            guard parent.didSetup else {
                return NineAnimatorPromise.fail(.providerError("Please login to Anilist and restart the app."))
            }
            let queue = DispatchQueue.global()
            return NineAnimatorPromise(queue: queue) {
                (callback: @escaping ((Void?, Error?) -> Void)) in
                // Request after 0.5 seconds to avoid congestion
                queue.asyncAfter(deadline: .now() + 0.5) {
                    callback((), nil)
                }
                return nil
            } .thenPromise {
                self.parent.graphQL(fileQuery: "AnilistUserRecommendations", variables: [
                    "page": 0,
                    "perPage": 50
                ])
            } .then {
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
