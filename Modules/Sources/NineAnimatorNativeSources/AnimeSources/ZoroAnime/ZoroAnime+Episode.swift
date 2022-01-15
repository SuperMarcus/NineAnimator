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
        "vidstreaming": "Vidstreaming",
        "vidcloud": "Vidcloud",
        "streamSB": "StreamSB",
        "streamtape": "Streamtape"
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
                
                let episodeList = try bowl.select(".server-item").compactMap {
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
                
                // serverId identifier
                // 4 - Vidstreaming
                // 1 - Vidcloud
                // 5 - StreamSB
                // 3 - Streamtape
                for (serverId, sourceId) in episodeList {
                    if serverId == "4" && link.server == "vidstreaming" {
                        episodeSource = sourceId
                    } else if serverId == "1" && link.server == "vidcloud" {
                        episodeSource = sourceId
                    } else if serverId == "5" && link.server == "streamSB" {
                        episodeSource = sourceId
                    } else if serverId == "3" && link.server == "streamtape" {
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
