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

extension NASourceMonosChinos {
    static let knownServers = [
        "Cloud": "MonosChinos",
        "Verystream": "VeryStream",
        "Fembed": "Fembed",
        "Clipwatching": "ClipWatching",
        "Uqload": "Uqload",
        "Mp4upload": "Mp4Upload",
        "Ok": "Ok",
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
            let playerId = try bowl.select("li[title=\(link.server)]").attr("data-tplayernv")

            // Check if server is available for this episode
            guard !playerId.isEmpty else {
                throw NineAnimatorError.responseError("This episode is not available on the selected server")
            }
            
            let playerElement = try bowl.select("#\(playerId)").html()
            
            let urlMatchingRegex = try NSRegularExpression(
                pattern: "\\?url=(.*)(?:&amp;|&)id",
                options: []
            )
            
            let urlParamMatch = try urlMatchingRegex
                .firstMatch(in: playerElement)
                .tryUnwrap(.responseError("Cannot find a valid URL to the resource"))
                .firstMatchingGroup
                .tryUnwrap()
            
            guard let serverUrl = urlParamMatch.removingPercentEncoding else {
                throw NineAnimatorError.responseError("Cannot find a valid URL to the resource")
            }
            
            let targetUrl = try URL(string: serverUrl).tryUnwrap()
            
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
