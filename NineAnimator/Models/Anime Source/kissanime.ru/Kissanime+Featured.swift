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

extension NASourceKissanime {
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        request(browsePath: "/").then {
            content in
            let bowl = try SwiftSoup.parse(content)
            
            let trendingAnimeList = try bowl.select("#tab-trending>div").compactMap {
                container -> AnimeLink? in
                if let linkString = try? container.select("a").attr("href"),
                    let imageUrlString = try? container.select("img").attr("src"),
                    let title = try? container.select("span.title").text(),
                    let animeUrl = URL(string: linkString, relativeTo: self.endpointURL),
                    let artworkUrl = URL(string: imageUrlString, relativeTo: self.endpointURL) {
                    return AnimeLink(title: title, link: animeUrl, image: artworkUrl, source: self)
                }
                return nil
            }
            
            let updatedAnimeList = try bowl.select(".bigBarContainer .items div>a").compactMap {
                container -> AnimeLink? in
                if let linkString = try? container.attr("href"),
                    let imageUrlString = try? container.select("img").attr("srctemp"),
                    let animeUrl = URL(string: linkString, relativeTo: self.endpointURL),
                    let artworkUrl = URL(string: imageUrlString, relativeTo: self.endpointURL) {
                    let title = container.ownText()
                    return AnimeLink(title: title, link: animeUrl, image: artworkUrl, source: self)
                }
                return nil
            }
            
            return BasicFeaturedContainer(featured: trendingAnimeList, latest: updatedAnimeList)
        }
    }
}
