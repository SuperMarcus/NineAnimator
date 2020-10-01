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

extension NASourceHAnime {
    fileprivate struct Nuxt: Codable {
        let state: State
    }

    fileprivate struct State: Codable {
        let data: DataObject
    }

    fileprivate struct DataObject: Codable {
        let video: Video
    }

    fileprivate struct Video: Codable {
        let hentaiVideo: HentaiVideo
        let videosManifest: VideoManifest
    }

    fileprivate struct HentaiVideo: Codable {
        let name: String
        let slug: String
        let releasedAt: String
        let description: String
        let coverUrl: String
        let likes: Int
        let dislikes: Int
    }
    
    fileprivate struct VideoManifest: Codable {
        let servers: [Server]
    }
    
    fileprivate struct Server: Codable {
        let streams: [Streams]
    }
    
    fileprivate struct Streams: Codable {
        let height: String
        let url: String
    }
    
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager.request(
            url: link.link,
            handling: .browsing
        ) .responseString.then {
            responseContent -> Anime in
            
            guard var serializedAnimeJson = NASourceHAnime
                .animeObjMatchingRegex
                .firstMatch(in: responseContent)?
                .firstMatchingGroup else {
                    throw NineAnimatorError.providerError("Couldn't find NUXT data")
            }

            if serializedAnimeJson.hasSuffix(";") {
                serializedAnimeJson.removeLast()
            }
            
            let jsonData = try serializedAnimeJson.data(using: .utf8)
                    .tryUnwrap(.providerError("Couldn't encode JSON data"))
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let hInfo = try decoder.decode(Nuxt.self, from: jsonData)
            
            let hVideo = hInfo.state.data.video.hentaiVideo
            let videoMani = hInfo.state.data.video.videosManifest
            
            let animeTitle = hVideo.name
            
            let artworkString = try self.jetpack(url: hVideo.coverUrl, quality: 100, cdn: "cps")
            let animeArtworkUrl = URL(string: artworkString) ?? link.image
            
            let reconstructedAnimeLink = AnimeLink(
                title: animeTitle,
                link: link.link,
                image: animeArtworkUrl,
                source: self
            )
            
            let animeDescription = hVideo
                .description
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            
            var additionalAnimeAttributes = [Anime.AttributeKey: Any]()
            
            let total = Float(hVideo.likes + hVideo.dislikes)
            let rate = ((Float(hVideo.likes) / total) * 100) / 10
            additionalAnimeAttributes[.rating] = (rate * Float(10.0)).rounded() / Float(10.0)
            additionalAnimeAttributes[.ratingScale] = Float(10.0)
            
            // Get the first array item only has one
            let servers = try videoMani.servers.first.tryUnwrap(.decodeError)
            let streams = servers.streams.filter { !$0.url.isEmpty }
            additionalAnimeAttributes["hanime.sources"] = Dictionary(uniqueKeysWithValues: streams.map {
                ($0.height, $0.url)
            })
            
            let dateOldFormatter = DateFormatter()
            dateOldFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            let dateNewFormatter = DateFormatter()
            dateNewFormatter.dateStyle = .medium

            if let releasedOldDate = dateOldFormatter.date(from: hVideo.releasedAt) {
                let releasedDate = dateNewFormatter.string(from: releasedOldDate)
                additionalAnimeAttributes[.airDate] = releasedDate
            }
            
            let episode = EpisodeLink(
                identifier: hVideo.slug,
                name: "1",
                server: "hanime.tv",
                parent: reconstructedAnimeLink
            )
            
            return Anime(
                reconstructedAnimeLink,
                alias: "",
                additionalAttributes: additionalAnimeAttributes,
                description: animeDescription,
                on: [ "hanime.tv": "HAnime" ],
                episodes: [ "hanime.tv": [ episode ] ]
            )
        }
    }
}
