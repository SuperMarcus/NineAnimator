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
import NineAnimatorCommon
import SwiftSoup

extension NASourceAnimeDao {
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        self.requestManager.request(
            url: endpointURL,
            handling: .browsing
        ) .responseString
          .then {
            responseContent in
            let bowl = try SwiftSoup.parse(responseContent)
            let updatedAnimeContainer = try bowl.select("div[aria-labelledby=\"latest-tab\"]")
            let featuredAnimeContainer = try bowl.select("div[aria-labelledby=\"ongoing-tab\"]")
            
            let updatedAnimeList = try updatedAnimeContainer
                .select(">div .card-body")
                .compactMap {
                    container -> AnimeLink? in
                    if let imageContainer = try container.select(".animeposter > div > a > img").first(),
                        let titleContainer = try container.select(".animeinfo > a").first() {
                        let animeTitle = try titleContainer.select(".animeinfo_top .animename").text()
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let animeUrl = try URL(
                            string: try container.select(".animeinfo > .animeparent").attr("href"),
                            relativeTo: self.endpointURL
                        ).tryUnwrap()
                        let artworkUrl = try URL(
                            string: try imageContainer.attr("data-src"),
                            relativeTo: self.endpointURL
                        ).tryUnwrap()
                        
                        // Construct and return the url
                        return AnimeLink(
                            title: animeTitle,
                            link: animeUrl,
                            image: artworkUrl,
                            source: self
                        )
                    }
                    return nil
                }
            
            let featuredAnimeList = try featuredAnimeContainer
                .select(">div:last-child .card-body")
                .compactMap {
                    container -> AnimeLink? in
                    if let imageContainer = try container.select(".animeposter > div > a > img").first(),
                        let titleContainer = try container.select(".animeinfo > a > div > span").first(),
                        let linkContainer = try container.select(".animeinfo > a").first() {
                        let animeTitle = titleContainer
                            .ownText()
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let animeUrl = try URL(
                            string: try linkContainer.attr("href"),
                            relativeTo: self.endpointURL
                        ).tryUnwrap()
                        let artworkUrl = try URL(
                            string: try imageContainer.attr("data-src"),
                            relativeTo: self.endpointURL
                        ).tryUnwrap()
                        
                        // Construct and return the url
                        return AnimeLink(
                            title: animeTitle,
                            link: animeUrl,
                            image: artworkUrl,
                            source: self
                        )
                    }
                    return nil
                }
            
            return BasicFeaturedContainer(
                featured: featuredAnimeList,
                latest: updatedAnimeList
            )
        }
    }
}
