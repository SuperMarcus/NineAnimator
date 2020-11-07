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

    struct Featured: Codable {
        var data: [SearchResponseRecordsFeatured]
    }
    
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        requestManager.request(
            url: endpointURL,
            handling: .browsing
        ) .responseData
          .thenPromise {
            episodePageContent in
            let data = episodePageContent
            let utf8Text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            let bowl = try SwiftSoup.parse(utf8Text)
            var encoded = try bowl.select("the-carousel").attr("animes")
            encoded = encoded.replacingOccurrences(of: "\n", with: "")
            let data_json = try encoded.data(using: .utf8).tryUnwrap()
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let user: [SearchResponseRecordsFeatured] = try decoder.decode([SearchResponseRecordsFeatured].self, from: data_json)
            let decodedResponse = user
            let recentAnimeLinks = try decodedResponse.map {
                record -> AnimeLink in
                let link = self.endpointURL.absoluteString + "/anime/"+String(record.id)+"-"+record.slug
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
            return self.requestManager.request(
                url: self.endpointURL.absoluteString + "/top-anime",
                handling: .browsing,
                query: [ "popular": "true" ]
            ) .responseData
          .then {
            responseContent in
            let dataFeatured = responseContent
            let utf8TextFeatured = String(data: dataFeatured, encoding: .utf8) ?? String(decoding: dataFeatured, as: UTF8.self)
            let bowlFeatured = try SwiftSoup.parse(utf8TextFeatured)
            var encodedFeatured = try bowlFeatured.select("top-anime").attr("animes")
            encodedFeatured = encodedFeatured.replacingOccurrences(of: "\n", with: "")
            let data_jsonFeatured = try encodedFeatured.data(using: .utf8).tryUnwrap()
            let decoderFeatured = JSONDecoder()
            decoderFeatured.keyDecodingStrategy = .convertFromSnakeCase
            let userFeatured: Featured = try decoderFeatured.decode(Featured.self, from: data_jsonFeatured)
            let decodedResponseFeatured = userFeatured.data
            let FeaturedAnimeLinks = try decodedResponseFeatured.map {
                record -> AnimeLink in
                let link = self.endpointURL.absoluteString + "/anime/"+String(record.id)+"-"+record.slug
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
                featured: Array(FeaturedAnimeLinks.prefix(10)),
                latest: Array(recentAnimeLinks.prefix(10))
            )
          }
        }
    }
}
