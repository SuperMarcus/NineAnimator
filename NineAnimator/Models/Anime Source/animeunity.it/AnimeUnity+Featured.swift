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

extension NASourceAnimeUnity {
    struct SearchResponseRecordsFeatured: Codable {
        var id: Int
        var title: String
        var imageurl: String
        var slug: String
    }
    
    private struct DummyCodableFeatured: Codable {}
    
    struct SearchResponseFeatured: Codable {
        var to_array: [SearchResponseRecordsFeatured]
        init(from decoder: Decoder) throws {
            var to_array = [SearchResponseRecordsFeatured]()
            var container = try decoder.unkeyedContainer()
            while !container.isAtEnd {
                if let route = try? container.decode(SearchResponseRecordsFeatured.self) {
                    to_array.append(route)
                } else {
                    _ = try? container.decode(DummyCodableFeatured.self) // <-- TRICK
                }
            }
            self.to_array = to_array
        }
    }
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        requestManager.request(
            url: endpointURL,
            handling: .browsing
        ) .responseData
          .then { responseContent in
            //div.text-center>div.text-center>div a
            //div.current-anime>div.row>div a
            let data = responseContent
            let utf8Text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            let  bowl = try SwiftSoup.parse(utf8Text)
            let new_json = bowl.debugDescription.components(separatedBy: "<the-carousel animes=\"")
            let json = new_json[1].components(separatedBy: "\" class=")
            let encoded = json[0]
            let decoded = encoded.stringByDecodingHTMLEntitiesAnime
            let data_json = decoded.data(using: .utf8)!
            let decoder: JSONDecoder = JSONDecoder.init()
            let user: SearchResponseFeatured = try decoder.decode(SearchResponseFeatured.self, from: data_json)
            let decodedResponse = user
            let recentAnimeLinks = try decodedResponse.to_array.map {
                record -> AnimeLink in
                let link = "https://animeunity.it/anime/"+String(record.id)+"-"+record.slug
                var animeUrlBuilder = try URLComponents(
                    url: link.asURL(),
                    resolvingAgainstBaseURL: true
                ).tryUnwrap()
                animeUrlBuilder.queryItems = [
                    .init(name: "id", value: "1")
                ]
                return AnimeLink(
                    title: record.title,
                    link: try animeUrlBuilder.url.tryUnwrap(),
                    image: try record.imageurl.asURL(),
                    source: self
                )
            }

            return BasicFeaturedContainer(
                featured: [],
                latest: recentAnimeLinks
            )
        }
    }
}
