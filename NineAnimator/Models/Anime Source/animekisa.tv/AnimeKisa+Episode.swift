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

extension NASourceAnimeKisa {
    static let knownServers = [
        "vidstreaming": "VidStreaming",
        "fembed": "Fembed",
        "hydrax": "HydraX",
        "mp4upload": "Mp4Upload"
    ]
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise.firstly {
            URL(string: link.identifier, relativeTo: link.parent.link)
        } .thenPromise {
            url in self.request(browseUrl: url).then { (url, $0) }
        } .then {
            episodeUrl, responseContent in
            let resourceMap = try self.collectSources(fromContent: responseContent)
            if let resourcePath = resourceMap[link.server] {
                let targetUrl = try URL(string: resourcePath).tryUnwrap(.urlError)
                // Construct the episode object
                return Episode(
                    link,
                    target: targetUrl,
                    parent: anime,
                    referer: episodeUrl.absoluteString,
                    userInfo: [:]
                )
            } else {
                throw NineAnimatorError.EpisodeServerNotAvailableError(
                    unavailableEpisode: link,
                    alternativeEpisodes: resourceMap.map {
                        server, _ in EpisodeLink(
                            identifier: link.identifier,
                            name: link.name,
                            server: server,
                            parent: link.parent
                        )
                    },
                    updatedServerMap: NASourceAnimeKisa.knownServers
                )
            }
        }
    }
    
    func collectSources(fromContent episodePage: String) throws -> [String: String] {
        let buildExp = {
            (needle: String) throws -> NSRegularExpression in
            try NSRegularExpression(pattern: "var \(needle)\\s+=\\s+\\\"([^\"]+)", options: [])
        }
        var obtainedSources = [
            "adless": try buildExp("GoogleVideo"),
            "rapidvideo": try buildExp("RapidVideo"),
            "fembed": try buildExp("Fembed"),
            "mp4upload": try buildExp("MP4Upload"),
            "openload": try buildExp("Openload"),
            "streamango": try buildExp("Streamango"),
            "vidstreaming": try buildExp("VidStreaming"),
            "hydrax": try buildExp("Hydrax")
        ] .compactMapValues { $0.firstMatch(in: episodePage)?.firstMatchingGroup }
          .compactMapValues { $0.isEmpty ? nil : $0 }
        
        if let adlessSource = obtainedSources["adless"] {
            let resolutionMatch = try NSRegularExpression(pattern: "\\d+\\|([^|]+)", options: [])
            let finalSelectedSource = resolutionMatch
                .lastMatch(in: adlessSource)? // Select the highest quality resource
                .firstMatchingGroup
            obtainedSources["adless"] = finalSelectedSource ?? adlessSource
        }
        
        return obtainedSources
    }
}
