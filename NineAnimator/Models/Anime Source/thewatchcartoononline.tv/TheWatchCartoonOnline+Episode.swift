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

extension NASourceTheWatchCartoonOnline {
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise.firstly {
            try URL(string: link.identifier).tryUnwrap()
        } .thenPromise {
            episodePageUrl in self
                .requestManager
                .request(url: episodePageUrl, handling: .browsing)
                .responseString
        } .then {
            episodePageContent in
            let bowl = try SwiftSoup.parse(episodePageContent)
            let videoElement = try bowl.select("video>source")
            let videoSource: URL
            if videoElement.isEmpty() {
                // If no video element is present, try decoding the video asset url
                // from the PACKER script
                let decodedScript = try PackerDecoder().decode(episodePageContent)
                let sourceMatchingExpr = try NSRegularExpression(
                    pattern: "src=\\\\*\"([^\"\\\\]+)",
                    options: []
                )
                
                let videoSourcePath = sourceMatchingExpr
                    .firstMatch(in: decodedScript)?
                    .firstMatchingGroup
                videoSource = try URL(
                    string: try videoSourcePath.tryUnwrap(
                        .responseError("Unable to find the video asset associated with this episode.")
                    ),
                    relativeTo: link.parent.link
                ).tryUnwrap()
                Log.info("[NASourceTheWatchCartoonOnline] Resource found from packed scripts.")
            } else {
                let videourl = try videoElement.attr("src")
                let newString = videourl.replacingOccurrences(of: "’", with: "%E2%80%99")
                videoSource = try URL(string: newString) .tryUnwrap()
                Log.info("[NASourceTheWatchCartoonOnline] Resource found from page source.")
            }
            return Episode(
                link,
                target: videoSource,
                parent: anime
            )
        }
    }
}
