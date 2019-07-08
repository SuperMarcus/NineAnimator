//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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

extension NASourceKissanime {
    static let knownServers = [
        "rapidvideo": "RapidVideo",
        "openload": "OpenLoad",
        "mp4upload": "Mp4Upload",
        "streamango": "Streamango",
        "nova": "Nova Server",
        "beta": "Beta Server",
        "beta2": "Beta2 Server"
    ]
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        return NineAnimatorPromise.firstly {
            () -> URL? in
            let episodeRawUrl = try URL(
                string: link.identifier,
                relativeTo: anime.link.link
            ).tryUnwrap()
            var episodeUrlComponents = try URLComponents(
                url: episodeRawUrl,
                resolvingAgainstBaseURL: true
            ).tryUnwrap()
            
            // Rebuild the url with server parameter
            var queryItems = episodeUrlComponents.queryItems ?? []
            queryItems.append(.init(name: "s", value: link.server))
            episodeUrlComponents.queryItems = queryItems
            return episodeUrlComponents.url
        } .thenPromise {
            reconstructedUrl in self
                .request(browseUrl: reconstructedUrl)
                .then { (reconstructedUrl, $0) }
        } .then {
            reconstructedUrl, content in
            let bowl = try SwiftSoup.parse(content)
            
            // Check if an verification is needed to access this page
            if try bowl.select("head>title")
                .text()
                .trimmingCharacters(in: .whitespacesAndNewlines) == "Are You Human" {
                throw NineAnimatorError.authenticationRequiredError(
                    "KissAnime requires you to complete a verification before viewing the episode",
                    reconstructedUrl
                ).withSourceOfError(self)
            }
            
            // Check if the currently loading episode is the selected server
            if try !bowl.select("#selectServer>option[selected]").attr("value").hasSuffix(link.server) {
                throw NineAnimatorError.responseError("This episode is not available on the selected server")
            }
            
            let frameMatchingRegex = try NSRegularExpression(
                pattern: "\\$\\('#divMyVideo'\\)\\.html\\('([^']+)",
                options: []
            )
            
            let frameScriptSourceMatch = try frameMatchingRegex
                .firstMatch(in: content)
                .tryUnwrap(.responseError("Cannot find a valid URL to the resource"))
                .firstMatchingGroup
                .tryUnwrap()
            
            let parsedFrameElement = try SwiftSoup.parse(frameScriptSourceMatch).select("iframe")
            let targetLinkString = try parsedFrameElement.attr("src")
            let targetUrl = try URL(string: targetLinkString, relativeTo: reconstructedUrl).tryUnwrap()
            
            // Construct the episode object
            return Episode(
                link,
                target: targetUrl,
                parent: anime,
                referer: reconstructedUrl.absoluteString
            )
        }
    }
    
    /// Infer the episode number from episode name
    func inferEpisodeNumber(fromName name: String) -> Int? {
        do {
            let matchingRegex = try NSRegularExpression(
                pattern: "Episode\\s+(\\d+)",
                options: [.caseInsensitive]
            )
            let episodeNumberMatch = try matchingRegex
                .firstMatch(in: name)
                .tryUnwrap()
                .firstMatchingGroup
                .tryUnwrap()
            let inferredEpisodeNumber = Int(episodeNumberMatch)
            
            // Return the inferred value if it's valid
            if let eNumb = inferredEpisodeNumber, eNumb > 0 {
                return eNumb
            } else { return nil }
        } catch { return nil }
    }
}
