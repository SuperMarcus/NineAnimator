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

extension NASourceZoroAnime {
    fileprivate struct serverResponse: Decodable {
        let html: String
        let status: Bool
    }
    
    fileprivate struct episodeResponse: Decodable {
        let htmlGuide: String
        let link: String
        let server: Int
        let sources: [String]
        let tracks: [String]
        let type: String
    }
    
    static let knownServers = [
        "VidStreaming (Sub)": "VidStreaming (Sub)", // Uses rapidcloud parser
        "Vidcloud (Sub)": "Vidcloud (Sub)",         // Uses rapidcloud parser
        "Streamsb (Sub)": "Streamsb (Sub)",
        "Streamtape (Sub)": "Streamtape (Sub)"
    ]
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
            self.requestManager.request(
                url: self.ajaxEndpoint.appendingPathComponent("/v2/episode/servers"),
                handling: .ajax,
                query: [
                    "episodeId": link.identifier
                ]
            ) .responseDecodable(type: serverResponse.self).thenPromise {
                serverResponse in
                let bowl = try SwiftSoup.parse(serverResponse.html)
                let episodeSubOrDub = link.server.localizedCaseInsensitiveContains("sub") ? "sub" : "dub"
                let episodeList = try bowl.select(".servers-\(episodeSubOrDub) > .ps__-list > .server-item").compactMap {
                    episodeElement -> (serverId: String, sourceId: String) in
                    let serverId = try episodeElement.attr("data-server-id")
                    let sourceId = try episodeElement.attr("data-id")
                    
                    return (serverId, sourceId)
                }
                
                if episodeList.isEmpty {
                    throw NineAnimatorError.responseError("No episode link found for this anime")
                }
                
                // Server Selection
                var episodeSource: String = ""
                
                // add support for subs & dubs
                
                // serverId identifier
                // 4 - VidStreaming
                // 1 - Vidcloud
                // 5 - Streamsb
                // 3 - Streamtape
                // There's probably a better way to do this
                for (serverId, sourceId) in episodeList {
                    if serverId == "4" && link.server.contains("VidStreaming") {
                        episodeSource = sourceId
                    } else if serverId == "1" && link.server.contains("Vidcloud") {
                        episodeSource = sourceId
                    } else if serverId == "5" && link.server.contains("Streamsb") {
                        episodeSource = sourceId
                    } else if serverId == "3" && link.server.contains("Streamtape") {
                        episodeSource = sourceId
                    }
                }
                
                return self.requestManager.request(
                    url: self.ajaxEndpoint.appendingPathComponent("/v2/episode/sources"),
                    handling: .ajax,
                    query: [ "id": episodeSource ]
                ).responseDecodable(type: episodeResponse.self).then {
                    episodeResponse in
                    return Episode(link, target: try URL(string: episodeResponse.link).tryUnwrap(), parent: anime)
                }
        }
    }
}
