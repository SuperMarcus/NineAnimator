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

extension NASourceAnimeFlv {
    static let knownServers = [
        "yuserver": "YUserver"
    ]
    
    static let urlRegex = try! NSRegularExpression(pattern: "https:\\\\/\\\\/www.+?(?=\")")
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        self.requestManager.request(url: link.identifier, handling: .browsing)
            .responseString
            .then {
                responseContent in
                let bowl = try SwiftSoup.parse(responseContent)
                let scriptText = try bowl.select("#AnimeFlv > script:nth-child(16)").outerHtml()
                let iframeURLString = try (NASourceAnimeFlv.urlRegex.firstMatch(in: scriptText))
                    .tryUnwrap()[0].replacingOccurrences(of: "\\", with: "")
                let iframeURL = try URL(string: iframeURLString).tryUnwrap()
                return Episode(
                link,
                target: iframeURL,
                parent: anime
            )
        }
    }
}
