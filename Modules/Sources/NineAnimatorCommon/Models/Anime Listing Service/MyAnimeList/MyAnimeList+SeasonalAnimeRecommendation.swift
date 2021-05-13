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

public extension MyAnimeList {
    class TrendingAnimeRecommendation: RecommendationSource {
        public let name = "Trending"
        public let priority: RecommendationSource.Priority = .defaultLow
        public var shouldPresentRecommendation: Bool { true }
        
        private let parent: MyAnimeList
        
        init(_ parent: MyAnimeList) {
            self.parent = parent
        }
        
        public func shouldReload(recommendation: Recommendation) -> Bool {
            false
        }
        
        public func generateRecommendations() -> NineAnimatorPromise<Recommendation> {
            parent.apiRequest(
                "/anime/ranking",
                query: [
                    "ranking_type": "trend",
                    "limit": 25,
                    "offset": 0,
                    "fields": "media_type,my_list_status{start_date,finish_date}"
                ]
            ) .then {
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
        public let name = "Seasonal Anime"
        public let priority: RecommendationSource.Priority = .defaultLow
        public var shouldPresentRecommendation: Bool { true }
        
        private let parent: MyAnimeList
        
        init(_ parent: MyAnimeList) {
            self.parent = parent
        }
        
        public func shouldReload(recommendation: Recommendation) -> Bool {
            false
        }
        
        public func generateRecommendations() -> NineAnimatorPromise<Recommendation> {
            let calendar = Calendar.current
            let date = Date()
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let season: String
            
            switch month {
            case 1...3: season = "Winter"
            case 4...6: season = "Spring"
            case 7...9: season = "Summer"
            case 10...12: season = "Fall"
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
                        "fields": "media_type,num_episodes,my_list_status{start_date,finish_date,num_episodes_watched}"
                    ]
                ) .then {
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
