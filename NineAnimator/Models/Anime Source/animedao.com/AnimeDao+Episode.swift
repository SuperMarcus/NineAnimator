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

extension NASourceAnimeDao {
    /// A list of servers that are known to exists on AnimeDao
    static let knownServerMap = [
        "#gstore": (name: "Google Video", switcher: "gstore"),
        "#hls": (name: "ProxyData", switcher: "hls"),
        "#gounlimited": (name: "GoUnlimited", switcher: "gounlimited"),
        "#fembed": (name: "Fembed", switcher: "fembed"),
        "#mixdrop": (name: "Mixdrop", switcher: "mixdrop"),
        "#hydrax": (name: "HydraX", switcher: "hydrax")
    ]
    
    static let attributeMatchingExpr = try! NSRegularExpression(
        pattern: "([^\\s=]+)=\"([^\"]+)",
        options: []
    )
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        let episodeIdentifierComponents = link.identifier.split(separator: "|")
        
        guard episodeIdentifierComponents.count > 1 else {
            return .fail(.decodeError("Cannot decode episode identifier '\(link.identifier)'"))
        }
        
        let serverIdentifier = Anime.ServerIdentifier(episodeIdentifierComponents[0])
        let episodePagePath = String(episodeIdentifierComponents[1])
        
        guard serverIdentifier == link.server else {
            return .fail(.decodeError("Inconsistent server and identifier"))
        }
        
        guard let serverInformation = NASourceAnimeDao.knownServerMap[serverIdentifier] else {
            return .fail(.decodeError("Unknown server '\(serverIdentifier)'"))
        }
        
        return NineAnimatorPromise.firstly {
            try URL(
                string: episodePagePath,
                relativeTo: self.endpointURL
            ).tryUnwrap()
        } .thenPromise {
            episodeUrl in self
                .requestManager
                .request(url: episodeUrl, handling: .browsing)
                .responseString
        } .thenPromise {
            responseContent in
            let bowl = try SwiftSoup.parse(responseContent)
            let availableServerList = try bowl
                .select("#videocontent li a")
                .map { try $0.attr("href") }
            
            // Mark if this asset uses dummy parser
            var isPassthroughLink = false
            
            // If this episode is not available on this server, provide
            // a list of alternatives.
            guard availableServerList.contains(serverIdentifier) else {
                let alternativeEpisodeLinks = availableServerList.map {
                    alternativeServer in EpisodeLink(
                        identifier: "\(alternativeServer)|\(episodePagePath)",
                        name: link.name,
                        server: alternativeServer,
                        parent: link.parent
                    )
                }
                let alternativeServerMap = NASourceAnimeDao.knownServerMap.mapValues {
                    $0.name
                }
                
                // Throw EpisodeServerNotAvailableError with the list of alternatives
                throw NineAnimatorError.EpisodeServerNotAvailableError(
                    unavailableEpisode: link,
                    alternativeEpisodes: alternativeEpisodeLinks,
                    updatedServerMap: alternativeServerMap
                )
            }
            
            let videoFrameUrl: URL
            
            if serverInformation.switcher == "gstore" {
                videoFrameUrl = try NASourceAnimeDao.locateInlineVideo(
                    link: link,
                    in: responseContent
                )
                isPassthroughLink = true
            } else {
                videoFrameUrl = try NASourceAnimeDao.locateFrameUrl(
                    serverInformation,
                    link: link,
                    in: responseContent
                )
            }
            
            return self.resolveRedirection(url: videoFrameUrl, episodeLink: link).then {
                referer, finalFrameUrl in Episode(
                    link,
                    target: finalFrameUrl,
                    parent: anime,
                    referer: referer,
                    userInfo: [ "I am dummy": isPassthroughLink ]
                )
            }
        }
    }
    
    private func resolveRedirection(url: URL, episodeLink: EpisodeLink) -> NineAnimatorPromise<(String, URL)> {
        let fallbackResult = (episodeLink.parent.link.absoluteString, url)
        guard url.pathComponents.contains("redirect") else {
            return .success(fallbackResult)
        }
        
        var destinationUrl: URL?
        var refererContent: String = episodeLink.parent.link.absoluteString
        return self
            .requestManager
            .request(url: url, handling: .browsing)
            .onRedirection {
                _, _, newRequest in
                destinationUrl = newRequest.url
                refererContent = newRequest.headers["Referer"] ?? refererContent
                return nil
            }
            .responseVoid
            .then {
                if let destinationUrl = destinationUrl {
                    Log.info("[NASourceAnimeDao] Resolved animedao redirection url: %@", destinationUrl)
                    return (refererContent, destinationUrl)
                } else { return fallbackResult }
            }
    }
    
    private static func locateInlineVideo(link: EpisodeLink, in responseContent: String) throws -> URL {
        let inlineVideoSrcMatchingExpr = try NSRegularExpression(
            pattern: "src:\\s+'([^']+)",
            options: []
        )
        let inlineVideoResourcePath = try inlineVideoSrcMatchingExpr
            .firstMatch(in: responseContent)
            .tryUnwrap(.responseError("Unable to locate video asset"))
            .firstMatchingGroup
            .tryUnwrap()
        return try URL(
            string: inlineVideoResourcePath,
            relativeTo: animedaoStreamEndpoint
        ).tryUnwrap()
    }
    
    private static func locateFrameUrl(_ serverInformation: (name: String, switcher: String), link: EpisodeLink, in responseContent: String) throws -> URL {
        let frameMatchingExpr = try NSRegularExpression(
            pattern: "function\\s+\(serverInformation.switcher)[^<]+(<iframe[^>]+)",
            options: []
        )
        let attrMatchingExpr = NASourceAnimeDao.attributeMatchingExpr
        
        let frameTagContent = try (frameMatchingExpr
                .firstMatch(in: responseContent)?
                .firstMatchingGroup
            ).tryUnwrap(.responseError("Unable to find the video frame that belongs to the selected server"))
        let frameTagAttributes = Dictionary(
            attrMatchingExpr
                .matches(in: frameTagContent)
                .map { (
                    frameTagContent[$0.range(at: 1)],
                    frameTagContent[$0.range(at: 2)]
                ) }
        ) { $1 }
        
        let videoFramePath = try frameTagAttributes["src"].tryUnwrap(
            .responseError("Video frame did not specify an address")
        )
        
        return try URL(
            string: videoFramePath,
            relativeTo: link.parent.link
        ).tryUnwrap()
    }
}
