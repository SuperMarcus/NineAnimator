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

extension MyAnimeList {
    class UserRecommendations: RecommendationSource {
        let name: String = "Anime For You"
        
        let piority: Piority = .defaultLow
        
        private let parent: MyAnimeList
        
        init(_ parent: MyAnimeList) {
            self.parent = parent
        }
        
        func shouldReload(recommendation: Recommendation) -> Bool {
            false
        }
        
        func generateRecommendations() -> NineAnimatorPromise<Recommendation> {
            guard parent.didSetup else {
                return NineAnimatorPromise.fail(.providerError("Please login to MyAnimeList and restart the app."))
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
                [weak self] in
                self?.parent.apiRequest(
                    "/anime/suggestions",
                    query: [
                        "limit": 50,
                        "offset": 0,
                        "fields": "media_type,num_episodes,my_list_status{start_date,finish_date,num_episodes_watched}"
                    ]
                )
            } .then {
               [weak self] responseObject in
               guard let self = self else { return nil }
               let references = try responseObject.data.compactMap {
                   entry -> ListingAnimeReference? in
                   let referenceNode = try entry.value(at: "node", type: NSDictionary.self)
                   let reference = try? ListingAnimeReference(self.parent, withAnimeNode: referenceNode)
                   
                   // Try to construct the reference and donate the tracking
                   if let reference = reference {
                       let tracking = self.parent.constructTracking(fromAnimeNode: referenceNode)
                       self.parent.donateTracking(tracking, forReference: reference)
                   }
                   
                   return reference
               }
               let items = references.map {
                   RecommendingItem(.listingReference($0))
               }
               return Recommendation(
                   self,
                   items: items,
                   title: "Anime For You",
                   subtitle: "MyAnimeList"
               ) {
                   [weak self] in
                   guard let self = self else { return nil }
                   return GenericAnimeList(
                       "/anime/suggestions",
                       parent: self.parent,
                       title: "Anime For You"
                   )
               }
           }
        }
    }
}
