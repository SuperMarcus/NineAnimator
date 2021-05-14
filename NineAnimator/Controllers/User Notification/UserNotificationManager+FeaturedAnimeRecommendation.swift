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

extension UserNotificationManager {
    class FeaturedAnimeRecommendation: RecommendationSource {
        var name = "Featured Anime"
        
        var priority: Priority = .defaultMedium
        
        var shouldPresentRecommendation: Bool {
            // Hide recommendation source if the currently
            // selected anime source returned no featured anime
            return lastDisplayedSourceHasFeatured ||
                (NineAnimator.default.user.source.name != currentlyLoadedSource.name)
        }
        
        var currentlyLoadedSource = NineAnimator.default.user.source
        var lastDisplayedSourceHasFeatured = true
        
        // This source also controls its child recommendation source
        lazy var latestAnimeRecommendationSource = { LatestAnimeRecommendation(self) }()
        
        func shouldReload(recommendation: Recommendation) -> Bool {
            // Reload if the user changed currently selected source
            NineAnimator.default.user.source.name != currentlyLoadedSource.name
        }
        
        func generateRecommendations() -> NineAnimatorPromise<Recommendation> {
            NineAnimatorPromise<FeaturedContainer> {
                self.currentlyLoadedSource = NineAnimator.default.user.source
                return self.currentlyLoadedSource.featured($0)
            } .then { result in
                let featuredItems = result.featured.map {
                    RecommendingItem(.anime($0))
                }
                
                self.lastDisplayedSourceHasFeatured = !featuredItems.isEmpty
                
                // Update child source as well
                let latestAnimeItems = result.latest.map {
                    RecommendingItem(.anime($0))
                }
                self.latestAnimeRecommendationSource.latestAnime = latestAnimeItems
                
                return Recommendation(
                    self,
                    items: featuredItems,
                    title: "Featured Anime",
                    subtitle: "On \(self.currentlyLoadedSource.name)"
                )
            }
        }
        
        /// Child source for Featured Anime Recommendation
        class LatestAnimeRecommendation: RecommendationSource {
            var name = "Latest Anime"
            
            var priority: Priority = .defaultMedium
            
            var shouldPresentRecommendation = false
            
            var latestAnime: [RecommendingItem] = [] {
                didSet {
                    shouldPresentRecommendation = !latestAnime.isEmpty
                    fireDidUpdateNotification()
                }
            }
            
            let parent: FeaturedAnimeRecommendation
            
            init(_ parent: FeaturedAnimeRecommendation) {
                self.parent = parent
            }
            
            func shouldReload(recommendation: Recommendation) -> Bool {
                recommendation.items != latestAnime
            }
            
            func generateRecommendations() -> NineAnimatorPromise<Recommendation> {
                .success(
                    .init(
                        self,
                        items: latestAnime,
                        title: "Latest Anime",
                        subtitle: "On \(parent.currentlyLoadedSource.name)"
                    )
                )
            }
        }
    }
}
