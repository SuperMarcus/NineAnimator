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

extension UserNotificationManager {
    class SubscribedAnimeRecommendationSource: RecommendationSource {
        var name = "Subscriptions"
        var priority: RecommendationSource.Priority = .defaultHigh
        var shouldPresentRecommendation: Bool { true }
        
        func shouldReload(recommendation: Recommendation) -> Bool {
            let currentlyDisplayedAnimeLinks: [AnimeLink] = recommendation.items.compactMap {
                switch $0.link {
                case .anime(let anime): return anime
                default: return nil
                }
            }
            return currentlyDisplayedAnimeLinks != NineAnimator.default.user.subscribedAnimes
        }
        
        func generateRecommendations() -> NineAnimatorPromise<Recommendation> {
            if NineAnimator.default.user.subscribedAnimes.isEmpty {
                return .fail(.searchError("You did not subscribe to any anime."))
            } else {
                return UserNotificationManager
                    .default
                    .animeWithNotifications()
                    .then {
                        [weak self] animeWithNotification in
                        guard let self = self else { return nil }
                        
                        // Map the anime with notifications
                        var recommendingItems = animeWithNotification.map {
                            RecommendingItem(
                                .anime($0),
                                caption: "New",
                                captionStyle: .highlight
                            )
                        }
                        
                        // Add the subscribed anime without updates
                        for anime in NineAnimator.default.user.subscribedAnimes {
                            if !animeWithNotification.contains(anime) {
                                recommendingItems.append(
                                    RecommendingItem(.anime(anime))
                                )
                            }
                        }
                        
                        // Construct the recommendation object
                        return Recommendation(self, items: recommendingItems, title: "Subscriptions")
                }
            }
        }
    }
}
