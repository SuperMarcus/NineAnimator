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

extension NASourceAnimePahe {
    // The same response as the other release response but different information
    // is needed for episode parsing
    fileprivate struct ReleaseResponse: Codable {
        var data: [ReleaseEpisodeItem]?
    }
    
    // Individual episode items
    fileprivate struct ReleaseEpisodeItem: Codable {
        // Only the identifier is important here
        var id: Int
        var episode: String
    }
    
    // Episode fetching Embed response
    fileprivate struct EmbedResponse: Codable {
        // response["data"]["<identifier>"]["<definition>"] => EmbedStreamingSourceItem
        var data: [String: [String: EmbedStreamingSourceItem]]
    }
    
    // An embed item
    fileprivate struct EmbedStreamingSourceItem: Codable {
        var url: String
    }
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise.firstly {
            () -> (animeIdentifier: String, episodeNumber: Int, page: String) in
            let decodedEpisodeIdentifiers = try formDecode(link.identifier)
            return (
                try decodedEpisodeIdentifiers["anime"].tryUnwrap(.decodeError),
                try Int(decodedEpisodeIdentifiers["episode"].tryUnwrap(.decodeError))
                    .tryUnwrap(.decodeError),
                try decodedEpisodeIdentifiers["page"].tryUnwrap(.decodeError)
            )
        } .thenPromise {
            (animeIdentifier: String, episodeNumber: Int, page: String) -> NineAnimatorPromise<(ReleaseResponse, Int)> in
            // Retrieve the real episode identifier
            self.request(
                ajaxPathDictionary: "/api",
                query: [
                    "m": "release",
                    "id": animeIdentifier,
                    "l": 30,
                    "sort": "episode_asc",
                    "page": page
                ]
            ) .then {
                (
                    try DictionaryDecoder().decode(ReleaseResponse.self, from: $0),
                    episodeNumber
                )
            }
        } .thenPromise {
            release, episodeNumber -> NineAnimatorPromise<(EmbedResponse, String)> in
            let episodeEntry = try release.data
                .tryUnwrap(.responseError("No episodes were found in this anime"))
                .first { Int($0.episode) == episodeNumber }
                .tryUnwrap(.responseError("This episode does not exists"))
            let selectedProvider = link.server
            
            // Retrieve streming target
            return self.request(
                ajaxPathDictionary: "/api",
                query: [
                    "m": "embed",
                    "id": episodeEntry.id,
                    "p": selectedProvider
                ]
            ) .then { (
                try DictionaryDecoder().decode(EmbedResponse.self, from: $0),
                String(episodeEntry.id)
            ) }
        } .then {
            embed, episodeIdentifier in
            let allDefinitions = try embed.data[episodeIdentifier].tryUnwrap(
                .responseError("Unable to extract streaming source by definitions")
            )
            
            // Get the highest definition item
            let selectedItem = try (allDefinitions["1080p"] ?? allDefinitions["720p"] ?? allDefinitions.map { $0.value }.last)
                .tryUnwrap(.responseError("No streaming source found for this episode"))
            let targetUrl = try URL(string: selectedItem.url).tryUnwrap(.urlError)
            
            // Construct the episode object
            return Episode(
                link,
                target: targetUrl,
                parent: anime,
                referer: "https://animepahe.com/"
            )
        }
    }
}
