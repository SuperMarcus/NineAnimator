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
    struct SearchResponseRecordsAnime: Codable {
        var number: String = ""
        var link: String = ""
    }
    
    private struct DummyCodableAnime: Codable {}
    
    struct SearchResponseAnime: Codable {
        var to_array: [SearchResponseRecordsAnime]
        init(from decoder: Decoder) throws {
            var to_array = [SearchResponseRecordsAnime]()
            var container = try decoder.unkeyedContainer()
            while !container.isAtEnd {
                if let route = try? container.decode(SearchResponseRecordsAnime.self) {
                    to_array.append(route)
                } else {
                    _ = try? container.decode(DummyCodableAnime.self) // <-- TRICK
                }
            }
            self.to_array = to_array
        }
    }
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager
            .request(url: link.link, handling: .browsing)
            .responseData
            .then {
                responseContent -> Anime in
                let data = responseContent
                let utf8Text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                let  bowl = try SwiftSoup.parse(utf8Text)
                let new_json = bowl.debugDescription.components(separatedBy: "episodes=\"")
                let json = new_json[1].components(separatedBy: "\" ")
                let encoded = json[0]
                let decoded = encoded.stringByDecodingHTMLEntitiesAnime
                let data_json = decoded.data(using: .utf8)!
                let decoder = JSONDecoder.init()
                let user: SearchResponseAnime = try decoder.decode(SearchResponseAnime.self, from: data_json)
                let decodedResponse = user
                let reconstructedAnimeLink = AnimeLink(
                    title: link.title,
                    link: link.link,
                    image: link.image,
                    source: self
                )
                // Obtain the list of episodes
                let episodesList = decodedResponse.to_array.map {
                    episode -> (EpisodeLink) in
                    let link_ep = episode.link.replacingOccurrences(of: "\\", with: "").dropLast(4)
                    return (EpisodeLink(
                        identifier: String(link_ep),
                        name: episode.number,
                        server: NASourceAnimeUnity.AnimeUnityStream,
                        parent: reconstructedAnimeLink
                    ))
                }
                // Information
                let synopsis = try bowl.select("div.description").text()
                // Attributes
                var additionalAttributes = [Anime.AttributeKey: Any]()
                _ = try bowl.select("div.info-item").compactMap {entry -> Void in
                    if try entry.text().contains("Anno") {
                        let year = try entry.select("small").text()
                        additionalAttributes[.airDate] = year
                    }
                    if try entry.text().contains("Valutazione") {
                        let val = try entry.select("small").text()
                        let rating = (val as NSString).floatValue
                        additionalAttributes[.rating] = rating
                        additionalAttributes[.ratingScale] = Float(10.0)
                    }
                }
                return Anime(
                    reconstructedAnimeLink,
                    alias: "",
                    additionalAttributes: additionalAttributes,
                    description: synopsis,
                    on: [ NASourceAnimeUnity.AnimeUnityStream: "AnimeUnity" ],
                    episodes: [ NASourceAnimeUnity.AnimeUnityStream: episodesList]
                )
            }
    }
}
