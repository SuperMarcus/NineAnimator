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

// server constants, probably a much better way to do this
let FEMBED = "Fembed"
let UQLOAD = "uqload"
let PLAYERSB = "playersb"
let STREAMTAPE = "streamtape"
let VIDEOBIN = "videobin"
let MP4UPLOAD = "mp4upload"
let serverList = [FEMBED, UQLOAD, PLAYERSB, STREAMTAPE, VIDEOBIN, MP4UPLOAD]

extension NASourceMonosChinos {
    static let knownServers = [
        "Cloud": "MonosChinos",
        "Streamtape": "Streamtape",
        "Fembed": "Fembed",
        "Clipwatching": "ClipWatching",
        "Uqload": "Uqload",
        "Mp4upload": "Mp4Upload",
        //        "Ok": "Ok", Note: Commenting for now
        "Videobin": "Videobin",
        "Senvid2": "SendVid"
    ]

    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise.firstly {
            URL(string: link.identifier)
        } .thenPromise {
            url in self
                .requestManager
                .request(url: url, handling: .browsing)
                .responseString
                .then { (url, $0) }
        } .then {
            episodeUrl, responseContent in
            
            let bowl = try SwiftSoup.parse(responseContent)
            var encodedPlayerId = "" // because variable can't be guaranteed to have a value, needs further fixing from the loop below
            
            let episodeList = try bowl.select("#play-video > a").compactMap {
                episodeElement -> (serverId: String, sourceId: String) in
                let serverName = try episodeElement.text()
                let dataPlayerId = try episodeElement.attr("data-player")
                
                return (serverName, dataPlayerId )
            }
            
            for (serverName, dataPlayerId) in episodeList {
                for server in serverList {
                    // link.server is the server the NineAnimator user selected
                    if serverName.caseInsensitiveCompare(server) == .orderedSame && link.server.caseInsensitiveCompare(server) == .orderedSame {
                        encodedPlayerId = dataPlayerId
                    }
                }
            }
            
            let decodedData = Data(base64Encoded: encodedPlayerId)!
            let decodedString = String(data: decodedData, encoding: .utf8)!
            
            // Check if server is available for this episode
            guard !encodedPlayerId.isEmpty else {
                throw NineAnimatorError.responseError("This episode is not available on the selected server")
            }
            
            let urlMatchingRegex = try NSRegularExpression(
                pattern: "\\?url=(.*)",
                options: []
            )
            
            let urlParamMatch = try urlMatchingRegex
                .firstMatch(in: decodedString)
                .tryUnwrap(.responseError("Cannot find a valid URL to the resource"))
                .firstMatchingGroup
                .tryUnwrap()
            
            guard let serverUrl = urlParamMatch.removingPercentEncoding else {
                throw NineAnimatorError.responseError("Cannot find a valid URL to the resource")
            }
            
            var targetUrl = try URL(string: serverUrl).tryUnwrap()
            
            // Retrieve sendvid url from url parameter
            if serverUrl.contains("tvanime") && serverUrl.contains("?url=") {
                let parameter = serverUrl.components(separatedBy: "?url=")
                targetUrl = try URL(string: parameter[1]).tryUnwrap()
            }
            
            return Episode(
                link,
                target: targetUrl,
                parent: anime,
                referer: episodeUrl.absoluteString,
                userInfo: [:]
            )
        }
    }
}
