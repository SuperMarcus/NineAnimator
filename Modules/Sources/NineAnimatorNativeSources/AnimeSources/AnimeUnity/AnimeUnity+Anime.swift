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

extension NASourceAnimeUnity {
    struct SearchResponseRecordsAnime: Codable {
        var number: String = ""
        var createdAt: String? = ""
        var link: String = ""
    }
    struct  SearchResponseRecordsData: Codable {
        var titleEng: String?
    }
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager
            .request(url: link.link, handling: .browsing)
            .responseData
            .then {
                responseContent -> Anime in
                let data = responseContent
                var episodeAttributes = [EpisodeLink: Anime.AdditionalEpisodeLinkInformation]()
                let utf8Text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                let bowl = try SwiftSoup.parse(utf8Text)
                let decoder = JSONDecoder()
                // Info
                var encoded = try bowl.select("video-player").attr("anime")
                encoded = encoded.replacingOccurrences(of: "\n", with: "")
                let data_json = try encoded.data(using: .utf8).tryUnwrap()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let user: SearchResponseRecordsData
                    = try decoder.decode(SearchResponseRecordsData.self, from: data_json)
                // Episodes
                var ep = try bowl.select("video-player").attr("episodes")
                ep = ep.replacingOccurrences(of: "\n", with: "")
                let ep_json = try ep.data(using: .utf8).tryUnwrap()
                let ep_decoded: [SearchResponseRecordsAnime]
                    = try decoder.decode([SearchResponseRecordsAnime].self, from: ep_json)
                // Decode
                let reconstructedAnimeLink = AnimeLink(
                    title: link.title,
                    link: link.link,
                    image: link.image,
                    source: self
                )
                // Obtain the list of episodes
                let eng_title = user.titleEng
                let episodesMap = ep_decoded.map {
                        episodeInfo -> (EpisodeLink) in
                    let link_ep = String(episodeInfo.link.replacingOccurrences(of: "\\", with: "").dropLast(4))
                    var arr = (episodeInfo.createdAt ?? "").split(separator: " ")[0].split(separator: "-")
                    arr.reverse()
                    let dateString = arr.joined(separator: "-")
                    let ep = (EpisodeLink(
                        identifier: link_ep,
                        name: episodeInfo.number,
                        server: NASourceAnimeUnity.AnimeUnityStream,
                        parent: reconstructedAnimeLink
                        ))
                    let info = Anime.AdditionalEpisodeLinkInformation(
                        parent: ep,
                        airDate: dateString,
                        episodeNumber: Int(episodeInfo.number),
                        title: "Episodio " + episodeInfo.number
                    )
                    episodeAttributes[ep] = info
                    return (ep)
                }
                // Information
                let synopsis = try bowl.select("div.description").text()
                // Attributes
                let additionalAttributes = try bowl.select("div.info-item").reduce(into: [Anime.AttributeKey: Any]()) { attributes, entry in
                    if try entry.text().contains("Anno") {
                        let year = try entry.select("small").text()
                        attributes[.airDate] = year
                    }
                    if try entry.text().contains("Valutazione") {
                        let val = try entry.select("small").text()
                        let rating = (val as NSString).floatValue
                        attributes[.rating] = rating
                        attributes[.ratingScale] = Float(10.0)
                    }
                }
                return Anime(
                    reconstructedAnimeLink,
                    alias: eng_title ?? link.title,
                    additionalAttributes: additionalAttributes,
                    description: synopsis,
                    on: [ NASourceAnimeUnity.AnimeUnityStream: "AnimeUnity" ],
                    episodes: [ NASourceAnimeUnity.AnimeUnityStream: episodesMap ],
                    episodesAttributes: episodeAttributes
                )
            }
    }
}
