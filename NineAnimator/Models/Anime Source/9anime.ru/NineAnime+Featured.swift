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

extension NASourceNineAnime {
    fileprivate static let backdropCssUrlRegex = try! NSRegularExpression(
        pattern: "url\\(\\'([^']+)",
        options: []
    )
    
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        self.requestDescriptor().thenPromise {
            _ in self.requestManager.request(
                "home",
                handling: .browsing
            ).responseBowl
        } .then {
            bowl in
            let requestBaseUrl = self.endpointURL.appendingPathComponent("anime")
            
            let featuredLinks = try bowl.select(".swiper-wrapper>.swiper-slide.item").map {
                slideElement -> AnimeLink in
                let backdropStyle = try slideElement
                    .select(".backdrop")
                    .attr("style")
                let backdropImageString = try NASourceNineAnime
                    .backdropCssUrlRegex
                    .firstMatch(in: backdropStyle)
                    .tryUnwrap(.responseError("Unable to find the artwork link in the response."))
                    .firstMatchingGroup
                    .tryUnwrap()
                let backdropImage = try URL(
                    protocolRelativeString: backdropImageString,
                    relativeTo: requestBaseUrl
                ).tryUnwrap()
                let animeTitleElement = try slideElement.select("h2>a")
                let animePageLinkString = try animeTitleElement.attr("href")
                let animePageLink = try URL(
                    protocolRelativeString: animePageLinkString,
                    relativeTo: requestBaseUrl
                ).tryUnwrap()
                let animeTitle = try animeTitleElement.text()
                return AnimeLink(
                    title: animeTitle,
                    link: animePageLink,
                    image: backdropImage,
                    source: self
                )
            }
            
            return BasicFeaturedContainer(featured: featuredLinks, latest: [])
        }
    }
}
