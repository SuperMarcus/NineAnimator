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

extension NASourceAnimeSaturn {
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        requestManager.request(
            url: endpointURL,
            handling: .browsing
        ) .responseString
          .then { responseContent in
            //div.text-center>div.text-center>div a
            //div.current-anime>div.row>div a
            let endpointURL = self.endpointURL
            let bowl = try SwiftSoup.parse(responseContent)
            let recentadded = try bowl.select("div.container.p-3.shadow.rounded.bg-dark-as-box div.main-anime-card div a")
            let recentAnimeLinks = try recentadded.compactMap {
                aElement -> (a: Element, img: Element)? in
                if let imageElement = try aElement.select("img").first() {
                    return (aElement, imageElement)
                } else { return nil }
            } .reduce(into: [AnimeLink]()) {
                container, elements in
                if let artworkPath = try? elements.img.attr("src"),
                    let artworkUrl = URL(string: artworkPath, relativeTo: endpointURL),
                    let animeTitle = try? elements.a.attr("title"),
                    let animePath = try? elements.a.attr("href"),
                
                    let animeUrl = URL(string: animePath, relativeTo: endpointURL) {
                    // Construct and add anime link
                    container.append(.init(
                        title: animeTitle,
                        link: animeUrl,
                        image: artworkUrl,
                        source: self
                    ))
                }
            }

            return BasicFeaturedContainer(
                featured: [],
                latest: recentAnimeLinks
            )
        }
    }
}
