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

extension NASourceFourAnime {/*
    /// 4anime provides multiple links for each episode, however they are not shown to the user
    static let knownServers = [
        "server1": "Server 1",
        "server2": "Server 2",
        "server3": "Server 3",
        "server4": "Server 4"
    ]*/
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        .fail(.contentUnavailableError("4Anime is no longer available on NineAnimator"))/*
        NineAnimatorPromise.firstly {
            try URL(string: link.identifier).tryUnwrap()
        } .thenPromise {
            episodePageUrl in self.requestManager.request(
                url: episodePageUrl,
                handling: .browsing
            ).responseString
        } .then {
            episodePageContent in
            
            // MARK: Scraping Methods
            
            // Tries to extract link from PACKER script (via video tags)
            func server1Scraper() throws -> URL? {
                let bowl = try SwiftSoup.parse(episodePageContent)
                let packedScript = try bowl.select("#justtothetop > script").eq(1).html()
                let decodedScript = try PackerDecoder().decode(packedScript)
                
                let sourceMatchingExpr = try NSRegularExpression(
                    pattern: "src=\\\\*\"([^\"\\\\]+)",
                    options: []
                )
                if let sourceUrlString = sourceMatchingExpr
                        .firstMatch(in: decodedScript)?
                        .firstMatchingGroup,
                    let sourceUrl = URL(
                        string: sourceUrlString,
                        relativeTo: link.parent.link
                    ) {
                    // Video tag src attribute
                    Log.info("[NASourceFourAnime] Resource found from packed scripts (video tag).")
                    return sourceUrl
                }
                return nil
            }
            
            // Tries to find video element under the source tag nested in the video element
            func server2Scraper() throws -> URL? {
                let bowl = try SwiftSoup.parse(episodePageContent)
                let videoElement = try bowl.select("video")
                if !videoElement.isEmpty(),
                    let source = try videoElement.select("source").first(),
                    let videoUrl = URL(string: try source.attr("src")) {
                    Log.info("[NASourceFourAnime] Resource found from page source (nested).")
                    return videoUrl
                }
                return nil
            }
            
            // Decode the video asset url from the PACKER script
            func server3Scraper() throws -> URL? {
                let decodedScript = try PackerDecoder().decode(episodePageContent)
                
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
                    // JWPlayer setup script
                    Log.info("[NASourceFourAnime] Resource found from packed scripts (packer.jwplayer.setup).")
                    return jwPlayerUrl
                }
                return nil
            }
            
            // Tries to find a valid url from the page's video tag
            func server4Scraper() throws -> URL? {
                let bowl = try SwiftSoup.parse(episodePageContent)
                let videoElement = try bowl.select("video")
                if !videoElement.isEmpty(),
                   let videoUrl = URL(string: try videoElement.attr("src")) {
                    Log.info("[NASourceFourAnime] Resource found from page source.")
                    return videoUrl
                }
                return nil
            }
            
            var videoURL: URL?
            
            switch link.server {
            case "server1":
                videoURL = try server1Scraper()
            case "server2":
                videoURL = try server2Scraper()
            case "server3":
                videoURL = try server3Scraper()
            case "server4":
                videoURL = try server4Scraper()
            default: break
            }
            
            guard let unwrappedVideoURL = videoURL else {
                throw NineAnimatorError.providerError("Unable to retrieve video link for this server.")
            }
            
            return Episode(
                link,
                target: unwrappedVideoURL,
                parent: anime,
                userInfo: [
                    DummyParser.Options.headers: [
                        "User-Agent": self.sessionUserAgent,
                        "Referer": "https://4anime.to/"
                    ]
                ]
            )
        }*/
    }
}
