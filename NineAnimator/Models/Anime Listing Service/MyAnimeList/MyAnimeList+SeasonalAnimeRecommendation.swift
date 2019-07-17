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

extension MyAnimeList {
    class TrendingAnimeRecommendation: RecommendationSource {
        let name = "Trending"
        let piority: RecommendationSource.Piority = .defaultLow
        
        private let parent: MyAnimeList
        
        init(_ parent: MyAnimeList) {
            self.parent = parent
        }
        
        func shouldReload(recommendation: Recommendation) -> Bool {
            return false
        }
        
        func generateRecommendations() -> NineAnimatorPromise<Recommendation> {
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
                    "/anime/ranking",
                    query: [
                        "ranking_type": "trend",
                        "limit": 25,
                        "offset": 0,
                        "fields": "media_type,my_list_status{start_date,finish_date}"
                    ]
                )
            } .then {
                [weak self] responseObject in
                guard let self = self else { return nil }
                let formatter = DateFormatter()
                formatter.timeStyle = .none
                formatter.dateStyle = .full
                let references = try responseObject.data.compactMap {
                    entry -> ListingAnimeReference? in
                    let referenceNode = try entry.value(at: "node", type: NSDictionary.self)
                    return try? ListingAnimeReference(self.parent, withAnimeNode: referenceNode)
                }
                let items = references.map {
                    RecommendingItem(.listingReference($0))
                }
                return Recommendation(
                    self,
                    items: items,
                    title: "Trending",
                    subtitle: formatter.string(from: Date())
                ) {
                    [weak self] in
                    guard let self = self else { return nil }
                    return GenericAnimeList(
                        "/anime/ranking",
                        parent: self.parent,
                        title: "Trending",
                        parameters: [ "ranking_type": "trend" ]
                    )
                }
            }
        }
    }
    
    class SeasonalAnimeRecommendation: RecommendationSource {
        let name = "Seasonal Anime"
        let piority: RecommendationSource.Piority = .defaultLow
        
        private let parent: MyAnimeList
        
        init(_ parent: MyAnimeList) {
            self.parent = parent
        }
        
        func shouldReload(recommendation: Recommendation) -> Bool {
            return false
        }
        
        func generateRecommendations() -> NineAnimatorPromise<Recommendation> {
            let calendar = Calendar.current
            let date = Date()
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let season: String
            
            switch month {
            case 1...3: season = "Spring"
            case 4...6: season = "Summer"
            case 7...9: season = "Fall"
            case 10...12: season = "Winter"
            default: return .fail(.unknownError)
            }
            
            let requestPath = "/anime/season/\(year)/\(season.lowercased())"
            
            return parent
                .apiRequest(
                    requestPath,
                    query: [
                        "sort": "anime_num_list_users",
                        "limit": 50,
                        "offset": 0,
                        "fields": "media_type,my_list_status{start_date,finish_date}"
                    ]
                ) .then {
                    [weak self] responseObject in
                    guard let self = self else { return nil }
                    let references = try responseObject.data.compactMap {
                        entry -> ListingAnimeReference? in
                        let referenceNode = try entry.value(at: "node", type: NSDictionary.self)
                        return try? ListingAnimeReference(self.parent, withAnimeNode: referenceNode)
                    }
                    let items = references.map {
                        RecommendingItem(.listingReference($0))
                    }
                    return Recommendation(
                        self,
                        items: items,
                        title: "Seasonal Anime",
                        subtitle: "\(year) \(season)"
                    ) {
                        [weak self] in
                        guard let self = self else { return nil }
                        return GenericAnimeList(
                            requestPath,
                            parent: self.parent,
                            title: "Seasonal Anime",
                            parameters: [ "sort": "anime_num_list_users" ]
                        )
                    }
                }
        }
    }
}
