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
import SwiftSoup

extension Anilist {
    struct CalendarItem {
        var date: Date
        var episode: Int
        var mediaSynopsis: String
        var reference: ListingAnimeReference
    }
    
    func requestWeeklyCalendar() -> NineAnimatorPromise<[CalendarItem]> {
        // Fetch calendar items from the start of today
        let startOfToday = Calendar.current.startOfDay(for: Date())
        // to 7 days after
        let sevenDaysFromToday = startOfToday.addingTimeInterval(604800)
        
        return graphQL(fileQuery: "AniListCalendarQuery", variables: [
            "page": 0,
            "perPage": 50,
            "startTime": Int(startOfToday.timeIntervalSince1970),
            "endTime": Int(sevenDaysFromToday.timeIntervalSince1970)
        ]) .then {
            responseDictionary in
            let animeScheduleEntities = try responseDictionary.value(
                at: "Page.airingSchedules",
                type: [NSDictionary].self
            )
            
            return try animeScheduleEntities.map {
                animeScheduleEntry in
                let airingEpisode = try animeScheduleEntry.value(at: "episode", type: Int.self)
                let mediaEntry = try animeScheduleEntry.value(at: "media", type: NSDictionary.self)
                let reference = try ListingAnimeReference(self, withMediaEntry: mediaEntry)
                let airingTimestamp = try animeScheduleEntry.value(at: "airingAt", type: Int.self)
                let airingDate = Date(timeIntervalSince1970: TimeInterval(airingTimestamp))
                let synopsis = try SwiftSoup.parse(
                    try mediaEntry.value(at: "description", type: String.self)
                ).text()
                
                let item = CalendarItem(
                    date: airingDate,
                    episode: airingEpisode,
                    mediaSynopsis: synopsis,
                    reference: reference
                )
                return item
            }
        }
    }
    
    class ThisWeekRecommendationSource: RecommendationSource {
        let name = "This Week"
        let piority: RecommendationSource.Piority = .defaultHigh
        
        private var generatedRecommendation: Recommendation?
        private let parent: Anilist
        
        init(_ parent: Anilist) {
            self.parent = parent
        }
        
        func generateRecommendations() -> NineAnimatorPromise<Recommendation> {
            if let cachedRecommendation = generatedRecommendation {
                return .success(cachedRecommendation)
            }
            
            return parent
                .requestWeeklyCalendar()
                .then {
                    [name] calendarItems in
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    dateFormatter.doesRelativeDateFormatting = true
                    
                    let recommendationItems = calendarItems.map {
                        RecommendingItem(
                            .listingReference($0.reference),
                            caption: "Ep. \($0.episode)",
                            subtitle: dateFormatter.string(from: $0.date),
                            synopsis: $0.mediaSynopsis
                        )
                    }
                    
                    return Recommendation(
                        self,
                        items: recommendationItems,
                        title: name,
                        style: .thisWeek
                    )
                }
        }
    }
}
