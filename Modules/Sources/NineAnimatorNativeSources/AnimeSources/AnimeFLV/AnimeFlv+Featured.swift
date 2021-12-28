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

extension NASourceAnimeFlv {
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        self.requestManager.request(
            url: endpointURL,
            handling: .browsing
        ).responseString.then {
            responseContent in
            let bowl = try SwiftSoup.parse(responseContent)
            let featuredAnime = try bowl.select("ul.List-Animes")
                .first()
                .tryUnwrap(NineAnimatorError.decodeError("Cannot retrieve featured anime"))
                .select("li")
                .map {
                    animeContainer -> AnimeLink in
                    
                    let animeArtworkURL = try URL(
                        string: animeContainer.select("a > figure.Image > img").attr("src"),
                        relativeTo: self.endpointURL
                    ) ?? NineAnimator.placeholderArtworkUrl
                    let animeLink = try URL(
                        string: animeContainer.select("a").attr("href"),
                        relativeTo: self.endpointURL
                    ).tryUnwrap(NineAnimatorError.urlError)
                    
                    let animeTitle = try animeContainer.select("a h2.Title").text()
                    return AnimeLink(
                        title: animeTitle,
                        link: animeLink,
                        image: animeArtworkURL,
                        source: self
                    )
            }
            /*
            let ongoingAnime = try bowl.select("ul.List-Episodes")
                .first()
                .tryUnwrap(NineAnimatorError.decodeError("Cannot retrieve latest anime"))
                .select("li")
                .map {
                    animeContainer -> AnimeLink in
                    
                    let animeArtworkURL = try URL(
                        string: animeContainer.select("a figure.Image > img").attr("src"),
                        relativeTo: self.endpointURL
                    ) ?? NineAnimator.placeholderArtworkUrl
                    
                    let animeLink = try URL(
                        string: animeContainer.select("a").attr("href"),
                        relativeTo: self.endpointURL
                    ).tryUnwrap(NineAnimatorError.urlError)
                    
                    let animeTitle = try animeContainer.select("a h2.Title").text()
                    
                    return AnimeLink(
                        title: animeTitle,
                        link: animeLink,
                        image: animeArtworkURL,
                        source: self
                    )
            }
            */
            
            return BasicFeaturedContainer(
                featured: featuredAnime,
                latest: []
            )
        }
    }
}
