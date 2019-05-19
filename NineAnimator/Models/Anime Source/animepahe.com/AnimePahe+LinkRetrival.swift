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

extension NASourceAnimePahe {
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        return NineAnimatorPromise.firstly {
            let components = url.pathComponents
            return self.animeBaseUrl.appendingPathComponent(components[2])
        } .thenPromise {
            url in self.request(browseUrl: url).then { ($0, url) }
        } .then {
            responseContent, animeUrl in
            let bowl = try SwiftSoup.parse(responseContent)
            
            // Find the HD anime poster
            // This is the same as the implementation for retriving Anime
            let animePosterLink = try bowl.select(".anime-poster img").attr("data-src")
            let animePosterUrl = try URL(string: animePosterLink).tryUnwrap(.responseError("No artwork for this anime was found"))
            
            // Find the anime title in h1
            let animeTitle = try (bowl.select(".title-wrapper>h1").first()?.ownText())
                .tryUnwrap(.responseError("Cannot find a title for this anime"))
            
            // Construct the AnimeLink object
            return .anime(AnimeLink(
                title: animeTitle,
                link: animeUrl,
                image: animePosterUrl,
                source: self
            ))
        }
    }
}
