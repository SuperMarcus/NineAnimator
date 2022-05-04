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

extension NASourceZoroAnime {
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        self.requestManager.request("home", handling: .browsing)
            .responseBowl
            .then { bowl in
                let featuredLinks = try bowl.select(".trending-list > .swiper-container > .swiper-wrapper > .swiper-slide")
                    .map { item -> AnimeLink in
                        let animeURL = try URL(
                            string: item.select(".item > a").attr("href"),
                            relativeTo: self.endpointURL
                        ).tryUnwrap()
                        let animeTitle = try item.select(".item > .number > div.film-title").text()
                        let animeCoverURL = try URL(
                            protocolRelativeString: try item.select(".item > a > img").attr("data-src"),
                            relativeTo: self.endpointURL
                        ).tryUnwrap()
                        
                        return AnimeLink(
                            title: animeTitle,
                            link: animeURL,
                            image: animeCoverURL,
                            source: self
                        )
                    }
                
                let updatedLinks = try bowl.select(".block_area_home > .tab-content > .block_area-content")
                    .first().tryUnwrap(NineAnimatorError.decodeError("Cannot retrieve recently updated anime"))
                    .select(".film_list-wrap > .flw-item")
                    .map { item -> AnimeLink in
                        let animeURL = try URL(
                            string: item.select(".film-detail > .film-name > a").attr("href"),
                            relativeTo: self.endpointURL
                        ).tryUnwrap()
                        let animeTitle = try item.select(".film-detail > .film-name > a").text()
                        let animeCoverURL = try URL(
                            protocolRelativeString: try item.select(".film-poster > img.film-poster-img").attr("data-src"),
                            relativeTo: self.endpointURL
                        ).tryUnwrap()
                        
                        return AnimeLink(
                            title: animeTitle,
                            link: animeURL,
                            image: animeCoverURL,
                            source: self
                        )
                    }
                
                return BasicFeaturedContainer(featured: featuredLinks, latest: updatedLinks)
            }
    }
}
