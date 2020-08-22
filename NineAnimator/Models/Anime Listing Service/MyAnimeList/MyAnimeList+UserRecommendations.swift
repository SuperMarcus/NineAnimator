//
//  MyAnimeList+UserRecommendations.swift
//  NineAnimator
//
//  Created by Uttiya Dutta on 2020-08-20.
//  Copyright © 2020 Marcus Zhou. All rights reserved.
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
