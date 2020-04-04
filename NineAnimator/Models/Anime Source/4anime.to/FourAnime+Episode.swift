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

extension NASourceFourAnime {
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise.firstly {
            try URL(string: link.identifier).tryUnwrap()
        } .thenPromise {
            episodePageUrl in self.request(browseUrl: episodePageUrl)
        } .then {
            episodePageContent in
            let bowl = try SwiftSoup.parse(episodePageContent)
            let videoElement = try bowl.select("video")
            let videoSource: URL
            
            // If a valid url was found from the page's video tag
            if !videoElement.isEmpty(),
                let videoUrl = URL(string: try videoElement.attr("src")) {
                // Video element was found, using the presented one
                videoSource = videoUrl
                Log.info("[NASourceFourAnime] Resource found from page source.")
            } else {
                // If no video element is present, try decoding the video asset url
                // from the PACKER script
                let decodedScript = try PackerDecoder().decode(episodePageContent)
                
                // Two variants found from 4anime's site
                let sourceMatchingExpr = try NSRegularExpression(
                    pattern: "src=\\\\*\"([^\"\\\\]+)",
                    options: []
                )
                let jwPlayerSetupMatchingExpr = try NSRegularExpression(
                    pattern: "file:\\s*\"([^\"]+)",
                    options: []
                )
                
                if let jwPlayerUrlString = jwPlayerSetupMatchingExpr
                        .firstMatch(in: decodedScript)?
                        .firstMatchingGroup,
                    let jwPlayerUrl = URL(
                        string: jwPlayerUrlString,
                        relativeTo: link.parent.link
                    ) {
                    // 1. JWPlayer setup script
                    videoSource = jwPlayerUrl
                    Log.info("[NASourceFourAnime] Resource found from packed scripts (jwplayer.setup).")
                } else if let sourceUrlString = sourceMatchingExpr
                        .firstMatch(in: decodedScript)?
                        .firstMatchingGroup,
                    let sourceUrl = URL(
                        string: sourceUrlString,
                        relativeTo: link.parent.link
                    ) {
                    // 2. Video tag src attribute
                    videoSource = sourceUrl
                    Log.info("[NASourceFourAnime] Resource found from packed scripts (video tag).")
                } else {
                    throw NineAnimatorError.providerError("Unable to resolve playback url from provider response")
                }
            }
            
            return Episode(
                link,
                target: videoSource,
                parent: anime
            )
        }
    }
}
