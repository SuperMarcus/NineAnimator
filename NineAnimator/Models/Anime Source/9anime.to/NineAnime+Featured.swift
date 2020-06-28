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

struct NineAnimeFeatured: FeaturedContainer {
    static let featuredAnimesRegex = try! NSRegularExpression(
        pattern: "background-image: url\\(([^)]+)\\)",
        options: .caseInsensitive
    )
    
    let featured: [AnimeLink]
    
    let latest: [AnimeLink]
    
    init?(_ pageSource: String, with parent: NASourceNineAnime) throws {
        let bowl = try SwiftSoup.parse(pageSource)
        
        featured = try bowl.select("div.items.swiper-wrapper div.item.swiper-slide").compactMap {
            element -> AnimeLink? in
            do {
                let animeTitle = try element.select("a.name").text()
                let animeArtwork =  try NineAnimeFeatured
                    .featuredAnimesRegex
                    .firstMatch(in: try element.attr("style"))
                    .tryUnwrap()
                    .firstMatchingGroup
                    .tryUnwrap()
                let animeArtworkUrl = try URL(string: animeArtwork).tryUnwrap()
                let animeLinkString = try element.select("a.name").attr("href")
                let animeLink = try URL(string: animeLinkString).tryUnwrap()
                return AnimeLink(
                    title: animeTitle,
                    link: animeLink,
                    image: animeArtworkUrl,
                    source: parent
                )
            } catch {
                Log.error("[NASourceNineAnime.NineAnimeFeatured] Unable to parse featured anime item because of error: %@", error)
            }
            return nil
        }
        
        latest = try bowl.select("div.film-list div.inner").compactMap {
            element -> AnimeLink? in
            do {
                let animeTitle = try element.select("a.name").text()
                let animeArtwork = try element.select("a.poster img").attr("src")
                let animeArtworkUrl = try URL(string: animeArtwork).tryUnwrap()
                let animeLinkString = try element.select("a.poster").attr("href")
                let animeLink = try URL(string: animeLinkString).tryUnwrap()
                return AnimeLink(
                    title: animeTitle,
                    link: animeLink,
                    image: animeArtworkUrl,
                    source: parent
                )
            } catch {
                Log.error("[NASourceNineAnime.NineAnimeFeatured] Unable to parse recently updated anime item because of error: %@", error)
            }
            return nil
        }
//        let latestUpdateAnimesRegex: NSRegularExpression = {
//            let endpointMatch = parent._currentHost.replacingOccurrences(of: ".", with: "\\.")
//            return try! NSRegularExpression(pattern: "(https:\\/\\/\(endpointMatch)\\/watch[^\"]+)\"[^>]+>\\s+\\<img src=\"(https[^\"]+)\" alt=\"([^\"]+)[^>]+>", options: .caseInsensitive)
//        }()
//        let featuredAnimesMatches = NineAnimeFeatured.featuredAnimesRegex.matches(
//            in: pageSource, range: pageSource.matchingRange
//        )
//        self.featured = try featuredAnimesMatches.map {
//            guard let imageLink = URL(string: pageSource[$0.range(at: 1)]),
//                let animeLink = URL(string: pageSource[$0.range(at: 2)])
//                else { throw NineAnimatorError.responseError("parser error") }
//            let title = pageSource[$0.range(at: 3)]
//            return AnimeLink(title: title, link: animeLink, image: imageLink, source: parent)
//        }
//
//        let latestAnimesMatches = latestUpdateAnimesRegex.matches(
//            in: pageSource, range: pageSource.matchingRange
//        )
//        self.latest = try latestAnimesMatches.map {
//            guard let imageLink = URL(string: pageSource[$0.range(at: 2)]),
//                let animeLink = URL(string: pageSource[$0.range(at: 1)])
//                else { throw NineAnimatorError.responseError("parser error") }
//            let title = pageSource[$0.range(at: 3)]
//            return AnimeLink(title: title, link: animeLink, image: imageLink, source: parent)
//        }
    }
}

extension NASourceNineAnime {
    func featured(_ handler: @escaping NineAnimatorCallback<FeaturedContainer>) -> NineAnimatorAsyncTask? {
        request(browse: endpointURL.appendingPathComponent("anime"), headers: [:]) {
            value, error in
            guard let value = value else {
                return handler(nil, error)
            }
            
            do {
                let page = try NineAnimeFeatured(value, with: self)
                handler(page, nil)
            } catch {
                handler(nil, error)
            }
        }
    }
}
