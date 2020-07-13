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
    struct  SearchResponseRecordsData: Codable {
        var title_eng: String?
        var episodes: [SearchResponseRecordsAnime]
    }
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager
            .request(url: link.link, handling: .browsing)
            .responseData
            .then {
                responseContent -> Anime in
                let data = responseContent
                let utf8Text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                let bowl = try SwiftSoup.parse(utf8Text)
                var encoded = try bowl.select("video-player").attr("anime")
                encoded = encoded.replacingOccurrences(of: "\n", with: "")
                let data_json = encoded.data(using: .utf8)!
                let decoder = JSONDecoder.init()
                let user: SearchResponseRecordsData
                    = try decoder.decode(SearchResponseRecordsData.self, from: data_json)
                let decodedResponse = user
                let reconstructedAnimeLink = AnimeLink(
                    title: link.title,
                    link: link.link,
                    image: link.image,
                    source: self
                )
                // Obtain the list of episodes
                var eng_title = decodedResponse.title_eng
                if let theTitle = eng_title {
                    eng_title = theTitle
                } else {
                    eng_title = link.title
                }
                let episodesList = decodedResponse.episodes.compactMap {
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
                _ = try bowl.select("div.info-item").compactMap { entry -> Void in
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
                    alias: eng_title ?? "",
                    additionalAttributes: additionalAttributes,
                    description: synopsis,
                    on: [ NASourceAnimeUnity.AnimeUnityStream: "AnimeUnity" ],
                    episodes: [ NASourceAnimeUnity.AnimeUnityStream: episodesList]
                )
            }
    }
}
