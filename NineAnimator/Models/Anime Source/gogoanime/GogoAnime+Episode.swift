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

struct NAGogoAnimeEpisodeInformation {
    let path: String
    let sources: [String: URL]
    
    /// Retrieve the streaming source URL
    func target(on name: String) -> URL? {
        sources[name]
    }
}

extension NASourceGogoAnime {
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        episodeInformation(for: link.identifier)
            .then { information in
                guard let targetURL = information.target(on: link.server) else {
                    throw NineAnimatorError.providerError("This episode is not available on \(link.server)")
                }
                
                // Construct episode
                return Episode(
                    link,
                    target: targetURL,
                    parent: anime,
                    referer: "\(self.endpoint)\(link.identifier)"
                )
            }
    }
    
    /// Retrieve the episode information struct for the episode at the particular path
    func episodeInformation(for episodePath: String) -> NineAnimatorPromise<NAGogoAnimeEpisodeInformation> {
        requestManager.request(episodePath, handling: .browsing)
            .responseString
            .then { content in
                let bowl = try SwiftSoup.parse(content)
                
                // Parse the streaming sources
                var streamingSources = try bowl.select("div.anime_muti_link a").compactMap {
                    serverLinkContainer -> (String, URL)? in
                    // Remove the "Select this server thing"
                    try serverLinkContainer.select("span").remove()
                    let serverName = try serverLinkContainer.text().trimmingCharacters(in: .whitespaces)
                    guard let streamUrl = URL(
                        string: try serverLinkContainer.attr("data-video"),
                        relativeTo: self.endpointURL.appendingPathComponent(episodePath)
                    ) else { return nil }
                    return (serverName, streamUrl)
                }
                
                // Make sure there is any
                guard !streamingSources.isEmpty else {
                    throw NineAnimatorError.responseError("No streaming sources found for this anime")
                }
                
                //GogoAnime's "Vidstreaming" server is a collection of backup links to different servers, however there is currently no way for the user to select a backup link, so we are removing this server from the Dictionary of sources.
                
                //Keep in mind that GogoAnime's "Gogo server" does use the VidStreamingParser
                streamingSources.removeAll { $0.0 == "Vidstreaming" }
                
                // Construct the episode information structure
                return NAGogoAnimeEpisodeInformation(
                    path: episodePath,
                    sources: Dictionary(uniqueKeysWithValues: streamingSources)
                )
            }
    }
}
