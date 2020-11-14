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

extension NASourceNineAnime {
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        guard let pageInfo = anime.additionalAttributes[AnimeAttributeKey.animePageInfo] as? AnimeInfo else {
            Log.error(
                "[NASourceNineAnime] Trying to retrieve an episode (%@) for an anime (%@) that does not have an associated AnimeInfo object.",
                link.identifier,
                anime.link.link.absoluteString
            )
            return .fail(.unknownError("This anime object does not have an associated AnimeInfo."))
        }
        
        return requestDescriptor().thenPromise {
            descriptor in self.availableServers(
                of: pageInfo.siteId,
                refererLink: anime.link.link
            ) .then { ($0, descriptor) }
        } .thenPromise {
            serverInfo, descriptor in
            guard let resourceInfo = serverInfo.episodes.first(where: {
                    $0.link.path == link.identifier
                }) else {
                throw NineAnimatorError.responseError("This episode has disappeared.")
            }
            
            guard let dynamicResourceId = resourceInfo.resourceMap[link.server] else {
                let alternatives = resourceInfo.resourceMap.keys.map {
                    serverId in EpisodeLink(
                        identifier: resourceInfo.link.path,
                        name: resourceInfo.name,
                        server: serverId,
                        parent: anime.link
                    )
                }
                
                let newServerMap = serverInfo.servers.reduce(into: [Anime.ServerIdentifier: String]()) {
                    serverMap, server in serverMap[server.id] = server.name
                }
                
                // Episode not available on server
                throw NineAnimatorError.EpisodeServerNotAvailableError(
                    unavailableEpisode: link,
                    alternativeEpisodes: alternatives,
                    updatedServerMap: newServerMap
                )
            }
            
            return self.requestManager.request(
                "ajax/anime/episode",
                handling: .ajax,
                parameters: [
                    "id": dynamicResourceId
                ],
                headers: [
                    "Referer": resourceInfo.link.absoluteString
                ]
            ) .responseDecodable(type: EpisodeResponse.self)
              .then { ($0, descriptor, resourceInfo) }
        } .then {
            (response: EpisodeResponse, descriptor: SourceDescriptor, episodeInfo: EpisodeInfo) in
            let transformedUrlString = descriptor.transform(response.url)
            let targetUrl = try URL(string: transformedUrlString).tryUnwrap()
            
            return Episode(
                link,
                target: targetUrl,
                parent: anime,
                referer: episodeInfo.link.absoluteString
            )
        }
    }
}

// MARK: - Data Structures
extension NASourceNineAnime {
    struct EpisodeResponse: Codable {
        var url: String
    }
}
