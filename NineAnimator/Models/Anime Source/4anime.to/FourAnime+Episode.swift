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
            episodePageUrl in self.requestManager.request(
                url: episodePageUrl,
                handling: .browsing
            ).responseString
        } .then {
            episodePageContent in
            let bowl = try SwiftSoup.parse(episodePageContent)
            let videoElement = try bowl.select("video")
            let videoSource: URL
            
            let jwPlayerSetupMatchingExpr = try NSRegularExpression(
                pattern: "file:\\s*\"([^\"]+)",
                options: []
            )
            
            // If a valid url was found from the page's video tag
            if !videoElement.isEmpty(),
                let videoUrl = URL(string: try videoElement.attr("src")) {
                // Video element was found, using the presented one
                videoSource = videoUrl
                Log.info("[NASourceFourAnime] Resource found from page source.")
            } else if !videoElement.isEmpty(),
                let source = try videoElement.select("source").first(),
                let videoUrl = URL(string: try source.attr("src")) {
                // Video element found under the source tag nested in the video element
                videoSource = videoUrl
                Log.info("[NASourceFourAnime] Resource found from page source (nested).")
            } else if let jwPlayerUrlString = jwPlayerSetupMatchingExpr
                    .firstMatch(in: episodePageContent)?
                    .firstMatchingGroup,
                let jwPlayerUrl = URL(
                    string: jwPlayerUrlString,
                    relativeTo: link.parent.link
                ) {
                // Latest 4anime page appears to be including the jwplayer configs in plaintext
                videoSource = jwPlayerUrl
                Log.info("[NASourceFourAnime] Resource found from packed scripts (plain.jwplayer.setup).")
            } else {
                // If no video element is present, try decoding the video asset url
                // from the PACKER script
                let decodedScript = try PackerDecoder().decode(episodePageContent)
                
                // Two variants found from 4anime's site
                let sourceMatchingExpr = try NSRegularExpression(
                    pattern: "src=\\\\*\"([^\"\\\\]+)",
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
                    Log.info("[NASourceFourAnime] Resource found from packed scripts (packer.jwplayer.setup).")
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
                parent: anime,
                userInfo: [
                    DummyParser.Options.headers: [
                        "User-Agent": self.sessionUserAgent,
                        "Referer": "https://4anime.to/"
                    ]
                ]
            )
        }
    }
}
