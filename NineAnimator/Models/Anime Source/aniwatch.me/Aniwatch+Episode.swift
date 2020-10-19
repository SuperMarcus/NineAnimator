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

import Alamofire
import Foundation

extension NASourceAniwatch {
    static let knownServers = [
        "endub": "Aniwatch (English Dub)",
        "ensub": "Aniwatch (English Sub)",
        "dedub": "Aniwatch (German Dub)",
        "desub": "Aniwatch (German Sub)"
    ]
    
    // Aniwatch uses different servers names in different api endpoints.
    fileprivate static let serverLanguages = [
        "desub": "de-DE",
        "dedub": "de-DE-DUB",
        "ensub": "en-US",
        "endub": "en-US-DUB"
    ]
    
    fileprivate struct AniwatchEpisodeResponse: Decodable {
        let stream: AniwatchStream
    }
    
    fileprivate struct AniwatchStream: Decodable {
        let no_streams: Bool
        let src: AniwatchVideoLinks
    }
    
    fileprivate struct AniwatchVideoLinks: Decodable {
        let fullhd: String?
        let hd: String?
        let ld: String?
        let sd: String?
    }
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise<(Int, String, String)>.firstly {
            // Extract Episode ID, and convert server name
            guard let episodeID = Int(link.identifier), let episodeLang = NASourceAniwatch.serverLanguages[link.server] else { throw NineAnimatorError.urlError }
            // Extract Anime ID From Anime Link URL
            let animeID = anime.link.link.lastPathComponent
            guard !animeID.isEmpty else { throw NineAnimatorError.urlError }
            return (episodeID, episodeLang, animeID)
        } .thenPromise {
            episodeID, episodeLang, animeID -> NineAnimatorPromise<AniwatchEpisodeResponse> in
            self.requestManager.request(
                self.ajexEndpoint.absoluteString,
                handling: .default,
                method: .post,
                parameters: [
                    "action": "watchAnime",
                    "controller": "Anime",
                    "ep_id": episodeID,
                    "hoster": "",
                    "lang": episodeLang
                ],
                encoding: JSONEncoding(),
                headers: ["x-path": "/anime/\(animeID)"]
            ).responseDecodable(type: AniwatchEpisodeResponse.self)
        } .then {
            episodeResponse -> Episode in
            // Check if episode has available streams
            guard episodeResponse.stream.no_streams == false else {
                throw NineAnimatorError.EpisodeServerNotAvailableError(unavailableEpisode: link)
            }
            
            // Choose the best quality stream possible
            let episodeSources = episodeResponse.stream.src
            let episodeURLString = try (episodeSources.fullhd ?? episodeSources.hd ?? episodeSources.ld ?? episodeSources.sd).tryUnwrap(.EpisodeServerNotAvailableError(unavailableEpisode: link))
            
            let episodeURL = try URL(string: episodeURLString).tryUnwrap(.urlError)
            
            return Episode(
                link,
                target: episodeURL,
                parent: anime,
                userInfo: [
                    DummyParser.Options.headers: [
                        "User-Agent": self.sessionUserAgent,
                        "Referer": "https://aniwatch.me/",
                        "Origin": "https://aniwatch.me",
                        "sec-fetch-dest": "empty",
                        "sec-fetch-mode": "cors",
                        "sec-fetch-site": "same-site"
                    ],
                    DummyParser.Options.contentType: "application/x-mpegurl"
                ]
            )
        }
    }
}
