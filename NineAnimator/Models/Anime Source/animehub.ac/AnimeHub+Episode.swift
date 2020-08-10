//
//  AnimeHub+Episode.swift
//  NineAnimator
//
//  Created by Uttiya Dutta on 2020-08-08.
//  Copyright © 2020 Marcus Zhou. All rights reserved.
//

import Foundation

extension NASourceAnimeHub {
    static let knownServers = [
        "fserver": "Fserver",
        "fdserver": "FDserver",
        "xserver": "Xserver",
        "oserver": "Oserver",
        "mpserver": "MPserver",
        "yuserver": "YUserver",
        //"hserver": "Hserver" Excluding until we update HydraX parser
    ]

    static let urlRegex = try! NSRegularExpression(pattern: #"((([A-Za-z]{3,9}:(?:\/\/)?)(?:[-;:&=\+\$,\w]+@)?[A-Za-z0-9.-]+|(?:www.|[-;:&=\+\$,\w]+@)[A-Za-z0-9.-]+)((?:\/[\+~%\/.\w-_]*)?\??(?:[-\+=&;%@.\w_]*)#?(?:[\w]*))?)"#, options: .caseInsensitive)
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise<String>.firstly {
            // Extract Episode ID from EpisodeLink URL
            let episodeURLParams = try URL(string:link.identifier, relativeTo: self.endpointURL).tryUnwrap()
                .query
                .tryUnwrap()
            let episodeID = try formDecode(episodeURLParams).value(at: "ep", type: String.self)
            return episodeID
        } .thenPromise {
            episodeID in
            // Request api for episode iframe
            self.requestManager.request(
                "ajax/anime/load_episodes_v2",
                handling: .ajax,
                query: ["s": link.server],
                parameters: ["episode_id": episodeID]
            ).responseData.then {
                responseContent in
                // Convert response into NSDictionary
                let responseJSON = try JSONSerialization.jsonObject(with: responseContent, options: []) as! NSDictionary

                let iframe = try responseJSON.value(at: "value", type: String.self)
                
                // Extract URL from iframe
                var iframeURLString = try NASourceAnimeHub.urlRegex.firstMatch(in: iframe)
                    .tryUnwrap()
                    .firstMatchingGroup
                    .tryUnwrap()
                
                // Add URL scheme if not present
                if !iframeURLString.hasPrefix("https://") {
                    iframeURLString = "https://\(iframeURLString)"
                }
                
                let iframeURL = try URL(string: iframeURLString).tryUnwrap()
                
                return Episode(
                    link,
                    target: iframeURL,
                    parent: anime
                )
            }
        }
    }
}
