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
import SwiftSoup

extension Anilist {
    func requestWeeklyCalendar() -> NineAnimatorPromise<[Anilist.CalendarItem]> {
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
            [weak self] responseDictionary in
            guard let self = self else {
                return nil
            }
            
            let currentPage = try DictionaryDecoder().decode(
                GQLPage.self,
                from: try responseDictionary.value(at: "Page", type: [String: Any].self)
            )
            let scheduleItems = try currentPage.airingSchedules.tryUnwrap(.decodeError)
            
            return try scheduleItems.compactMap {
                scheduleItem -> CalendarItem? in
                let media = try scheduleItem.media.tryUnwrap(.decodeError)
                return !NineAnimator.default.user.allowNSFWContent && media.isAdult == true ? nil : CalendarItem(
                    date: Anilist.date(fromAnilistTimestamp: try scheduleItem.airingAt.tryUnwrap(.decodeError)),
                    episode: try scheduleItem.episode.tryUnwrap(.decodeError),
                    totalEpisodes: media.episodes,
                    mediaSynopsis: try SwiftSoup.parse(
                        media.description ?? "No synopsis found for this title."
                    ).text(),
                    reference: try ListingAnimeReference(
                        self,
                        withMediaObject: try scheduleItem.media.tryUnwrap(.decodeError)
                    )
                )
            }
        }
    }
    
    class ThisWeekRecommendationSource: RecommendationSource {
        let name = "This Week"
        let priority: RecommendationSource.Priority = .defaultHigh
        var shouldPresentRecommendation: Bool { true }
        
        private var generatedRecommendation: Recommendation?
        private let parent: Anilist
        
        init(_ parent: Anilist) {
            self.parent = parent
        }
        
        func shouldReload(recommendation: Recommendation) -> Bool {
            false
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
                    ) { WeeklyCalendar(self.parent) }
                }
        }
    }
}
