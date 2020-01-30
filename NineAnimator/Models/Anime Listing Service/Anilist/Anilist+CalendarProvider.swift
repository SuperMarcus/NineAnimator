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
    class WeeklyCalendar: CalendarProvider, AttributedContentProvider {
        private(set) var totalPages: Int?
        weak var delegate: ContentProviderDelegate?
        
        private var loadedItems = [[CalendarItem]]()
        private var loadingTask: NineAnimatorAsyncTask?
        private let parent: Anilist
        private let initialDate: Date
        
        func links(on page: Int) -> [AnyLink] {
            loadedItems[page].map { .listingReference($0.reference) }
        }
        
        func more() {
            guard loadingTask == nil, moreAvailable else { return }
            
            // Create the loading task
            self.loadingTask = parent.graphQL(fileQuery: "AniListCalendarQuery", variables: [
                "page": availablePages + 1,
                "perPage": 50,
                "startTime": Int(initialDate.timeIntervalSince1970)
            ]) .then {
                [weak self] responseDictionary -> [CalendarItem]? in
                guard let self = self else { return nil }
                
                let currentPage = try DictionaryDecoder().decode(
                    GQLPage.self,
                    from: try responseDictionary.value(at: "Page", type: [String: Any].self)
                )
                let scheduleItems = try currentPage.airingSchedules.tryUnwrap(.decodeError)
                
                let results = try scheduleItems.compactMap {
                    scheduleItem -> CalendarItem? in
                    let media = try scheduleItem.media.tryUnwrap(.decodeError)
                    return media.isAdult == true ? nil : CalendarItem(
                        date: Anilist.date(fromAnilistTimestamp: try scheduleItem.airingAt.tryUnwrap(.decodeError)),
                        episode: try scheduleItem.episode.tryUnwrap(.decodeError),
                        totalEpisodes: media.episodes,
                        mediaSynopsis: try media.description.tryUnwrap(.decodeError),
                        reference: try ListingAnimeReference(self.parent, withMediaObject: try scheduleItem.media.tryUnwrap(.decodeError))
                    )
                }
                
                guard !results.isEmpty else {
                    throw NineAnimatorError.searchError("No results found")
                }
                
                // If no more pages are available, save the total pages
                if currentPage.pageInfo?.hasNextPage == false {
                    self.totalPages = self.availablePages + 1
                }
                
                return results
            } .error {
                [weak self] error in
                guard let self = self else { return }
                self.loadingTask = nil
                self.delegate?.onError(error, from: self)
            } .finally {
                [weak self] results in
                guard let self = self else { return }
                let page = self.loadedItems.count
                self.loadingTask = nil
                self.loadedItems.append(results)
                self.delegate?.pageIncoming(page, from: self)
            }
        }
        
        func date(for link: AnyLink, on page: Int) -> Date {
            guard case let .listingReference(reference) = link else {
                return .distantPast
            }
            
            // Return the stored date in the item
            return loadedItems[page]
                .first { $0.reference == reference }?
                .date ?? .distantPast
        }
        
        func attributes(for link: AnyLink, index: Int, on page: Int) -> ContentAttributes? {
            let requestingItem = loadedItems[page][index]
            let subtitleText: String
            
            if let totalEpisodeNumber = requestingItem.totalEpisodes {
                subtitleText = "Ep. \(requestingItem.episode)/\(totalEpisodeNumber)"
            } else { subtitleText = "Ep. \(requestingItem.episode)" }
            
            return ContentAttributes(
                title: link.name,
                subtitle: subtitleText,
                description: requestingItem.mediaSynopsis
            )
        }
        
        init(_ parent: Anilist) {
            self.parent = parent
            self.initialDate = Calendar.current.startOfDay(for: Date())
        }
    }
    
    struct CalendarItem {
        var date: Date
        var episode: Int
        var totalEpisodes: Int?
        var mediaSynopsis: String
        var reference: ListingAnimeReference
    }
    
    static func date(fromAnilistTimestamp timestamp: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}

extension Anilist.WeeklyCalendar {
    var availablePages: Int { loadedItems.count }
    var moreAvailable: Bool { totalPages == nil }
    var title: String { "This Week" }
}
