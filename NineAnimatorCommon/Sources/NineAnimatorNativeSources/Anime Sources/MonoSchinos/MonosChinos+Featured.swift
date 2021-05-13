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

extension NASourceMonosChinos {
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        self.requestManager.request("/emision", handling: .browsing).responseString.then {
            responseContent in
            let bowl = try SwiftSoup.parse(responseContent)
            let seasonAnime = try bowl.select(".container > .row > article > a").map {
                animeContainer -> AnimeLink in
                let artworkUrl = URL(
                    string: try animeContainer.select(".Image > figure > img").attr("src")
                ) ?? NineAnimator.placeholderArtworkUrl
                
                let animeLink = try URL(
                    string: try animeContainer.select("a").attr("href")
                ).tryUnwrap()
                
                let animeTitle = try animeContainer
                    .select("h3.Title")
                    .text()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                return AnimeLink(
                    title: animeTitle,
                    link: animeLink,
                    image: artworkUrl,
                    source: self
                )
            }
            return BasicFeaturedContainer(featured: seasonAnime, latest: [])
        }
    }
}
