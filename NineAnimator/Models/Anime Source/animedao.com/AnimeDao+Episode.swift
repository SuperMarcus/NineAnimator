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
        "#hls": (name: "ProxyData", switcher: "hls"),
        "#gounlimited": (name: "GoUnlimited", switcher: "gounlimited"),
        "#fembed": (name: "Fembed", switcher: "fembed")
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
        let episodePagePath = episodeIdentifierComponents[1...]
            .joined(separator: "|")
        
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
            episodeUrl in self.request(browseUrl: episodeUrl)
        } .then {
            responseContent in
            let bowl = try SwiftSoup.parse(responseContent)
            let availableServerList = try bowl
                .select("#videocontent li a")
                .map { try $0.attr("href") }
            
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
            let videoFrameUrl = try URL(
                string: videoFramePath,
                relativeTo: link.parent.link
            ).tryUnwrap()
            
            return Episode(
                link,
                target: videoFrameUrl,
                parent: anime,
                referer: link.parent.link.absoluteString,
                userInfo: [:]
            )
        }
    }
}
