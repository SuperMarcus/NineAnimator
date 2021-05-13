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

extension NASourceAnimeHub {
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        self.requestManager.request(
            "/animehub.to",
            handling: .browsing
        ).responseString.then {
            responseContent in
            let bowl = try SwiftSoup.parse(responseContent)
            let featuredAnime = try bowl.select("ul.ulclear.grid-item.grid-item-featured")
                .first()
                .tryUnwrap(NineAnimatorError.decodeError("Cannot retrieve featured anime"))
                .select("li")
                .map {
                animeContainer -> AnimeLink in
                
                let animeArtworkURL = try URL(
                    string: animeContainer.select("a.thumb > img").attr("src")
                ) ?? NineAnimator.placeholderArtworkUrl
                
                let animeLink = try URL(
                    string: animeContainer.select("a.thumb").attr("href")
                ).tryUnwrap(NineAnimatorError.urlError)
                
                let animeTitle = try animeContainer.select("a.thumb").attr("title")
                
                return AnimeLink(
                    title: animeTitle,
                    link: animeLink,
                    image: animeArtworkURL,
                    source: self
                )
            }
            
            let ongoingAnime = try bowl.select("ul.ulclear.grid-item.grid-item-featured")[safe: 1]
                .tryUnwrap(NineAnimatorError.decodeError("Cannot retrieve latest anime"))
                .select("li")
                .map {
                    animeContainer -> AnimeLink in
                    
                    let animeArtworkURL = try URL(
                        string: animeContainer.select("a.thumb > img").attr("src")
                    ) ?? NineAnimator.placeholderArtworkUrl
                    
                    let animeLink = try URL(
                        string: animeContainer.select("a.thumb").attr("href")
                    ).tryUnwrap(NineAnimatorError.urlError)
                    
                    let animeTitle = try animeContainer.select("a.thumb").attr("title")
                    
                    return AnimeLink(
                        title: animeTitle,
                        link: animeLink,
                        image: animeArtworkURL,
                        source: self
                    )
            }
            
            return BasicFeaturedContainer(
                featured: featuredAnime,
                latest: ongoingAnime
            )
        }
    }
}
