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

extension NASourceFourAnime {
    static let animeLinkParsingRegex = try! NSRegularExpression(
        pattern: #"\/anime\/([^/]+)"#,
        options: .caseInsensitive
    )

    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        NineAnimatorPromise<URL>.firstly {
            let urlString = url.absoluteString
            
            let animeIdentifier = try (NASourceFourAnime.animeLinkParsingRegex.firstMatch(
            in: urlString)?.firstMatchingGroup)
                .tryUnwrap(.responseError("This 4anime link isnt supported."))
            
            let recontructedAnimeLink = try URL(
                string: "/anime/\(animeIdentifier)",
                relativeTo: self.endpointURL
            ).tryUnwrap(.responseError("This 4anime link is invalid"))
            return recontructedAnimeLink
        } .thenPromise {
            reconstructedAnimeLink in
            self.requestManager.request(
                url: reconstructedAnimeLink,
                handling: .browsing
            ).responseString
            .then { ($0, url) }
        } .then {
            responseContent, reconstructedAnimeLink in
            let bowl = try SwiftSoup.parse(responseContent)
            
            let animeTitle = try bowl.select(".content p").text()
            
            let animeArtworkUrl = try URL(
                string: try bowl.select(".cover>img").attr("src"),
                relativeTo: self.endpointURL
            ).tryUnwrap(.responseError("Cannot Find Anime Artwork"))
            
            return .anime(AnimeLink(
                title: animeTitle,
                link: reconstructedAnimeLink,
                image: animeArtworkUrl,
                source: self
            ))
        }
    }
}
