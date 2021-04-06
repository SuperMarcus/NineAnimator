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

extension NASourcePantsubase {
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        self.requestManager.request(endpoint)
            .responseBowl
            .then { bowl in
                let links = try bowl.select(".info-r > .episode.cont.contio > .list")
                    .map {
                        item -> AnimeLink in
                        let webLink = try URL(
                            string: item
                                .select(".itema > .link")
                                .attr("href")
                        ).tryUnwrap()
                        
                        let animeTitle = try item.select(".itema > .ani-name").text()
                        
                        var animeCover = try item.select(".itema > .link > img").attr("src")
                        
                        // Add https:// prefix if required
                        if animeCover.hasPrefix("//") {
                            animeCover = "https:" + (try animeCover
                                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                                .tryUnwrap(.urlError))
                        }
                        
                        let animeCoverURL = try URL(string: animeCover)
                            .tryUnwrap()
                        
                        return AnimeLink(
                            title: animeTitle,
                            link: webLink,
                            image: animeCoverURL,
                            source: self
                        )
                    }
                return BasicFeaturedContainer(featured: [], latest: links)
            }
    }
}
