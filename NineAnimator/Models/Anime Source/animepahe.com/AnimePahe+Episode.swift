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

extension NASourceAnimePahe {
    // Individual episode items
    struct ReleaseEpisodeItem: Codable {
        // Only the identifier is important here
        var id: Int
        var episode: Int
        var episode2: Int?
        var session: String?
    }
    
    // Episode fetching Embed response
    fileprivate struct EmbedResponse: Codable {
        // response["data"]["<identifier>"]["<definition>"] => EmbedStreamingSourceItem
        var data: [[String: EmbedStreamingSourceItem]]
    }
    
    // An embed item
    fileprivate struct EmbedStreamingSourceItem: Codable {
        var kwik: String
    }
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise.firstly {
            () -> (animeIdentifier: String, episodeNumber: Int, page: Int) in
            let decodedEpisodeIdentifiers = try formDecode(link.identifier)
            return (
                try decodedEpisodeIdentifiers["anime"].tryUnwrap(.decodeError),
                try Int(
                    decodedEpisodeIdentifiers["episode"].tryUnwrap(.decodeError)
                ) .tryUnwrap(.decodeError),
                try Int(
                    try decodedEpisodeIdentifiers["page"].tryUnwrap(.decodeError)
                ) .tryUnwrap(.decodeError)
            )
        } .thenPromise {
            animeIdentifier, episodeNumber, page in
            self.lookupReleaseEpisodeItem(
                animeIdentifier: animeIdentifier,
                episodeNumber: episodeNumber,
                lookupPage: page,
                originalPage: page
            ) .then { (animeIdentifier, $0) }
        } .thenPromise {
            animeIdentifier, episodeEntry in
            // Retrieve streming target
            self.requestManager.request(
                "/api",
                handling: .ajax,
                query: [
                    "m": "embed",
                    "id": animeIdentifier,
                    "p": link.server,
                    "session": episodeEntry.session ?? ""
                ]
            ) .responseDictionary
              .then { try DictionaryDecoder().decode(EmbedResponse.self, from: $0) }
        } .then {
            embed in
            let allDefinitions = Dictionary(embed.data.flatMap {
                $0.map { $0 }
            }) { $1 }
            
            // Get the highest definition item
            let selectedItem = try (allDefinitions["1080"] ?? allDefinitions["1080p"] ?? allDefinitions["720"] ?? allDefinitions["720p"] ?? allDefinitions.map { $0.value }.last)
                .tryUnwrap(.responseError("No streaming source found for this episode"))
            let targetUrl = try URL(string: selectedItem.kwik).tryUnwrap(.urlError)
            
            // Construct the episode object
            return Episode(
                link,
                target: targetUrl,
                parent: anime,
                referer: "https://animepahe.com/"
            )
        }
    }
    
    /// Lookup the episode release item
    fileprivate func lookupReleaseEpisodeItem(animeIdentifier: String, episodeNumber: Int, lookupPage: Int, originalPage: Int) -> NineAnimatorPromise<ReleaseEpisodeItem> {
        self.requestManager.request(
            "/api",
            handling: .ajax,
            query: [
                "m": "release",
                "id": animeIdentifier,
                "l": 30,
                "sort": "episode_asc",
                "page": lookupPage
            ]
        ) .responseDecodable(type: ReleaseResponse.self)
          .thenPromise {
            response in
            // Episode came before this page
            if response.from == nil || (response.data?.first?.episode ?? 0) > episodeNumber {
                let nextLookupPage = lookupPage - 1
                
                // Lookup at most 3 pages or people will get mad
                if nextLookupPage <= 0 || (originalPage - nextLookupPage) >= 3 {
                    return .fail(.responseError("Unable to find this episode"))
                }
                
                Log.info("[NASourceAnimePahe] Episode %@ not found in release page %@ (expected to be in page %@). Looking in page %@...", episodeNumber, lookupPage, originalPage, nextLookupPage)
                return self.lookupReleaseEpisodeItem(
                    animeIdentifier: animeIdentifier,
                    episodeNumber: episodeNumber,
                    lookupPage: nextLookupPage,
                    originalPage: originalPage
                )
            }
            
            return NineAnimatorPromise.firstly {
                try response.data
                    .tryUnwrap(.responseError("No episodes were found in this anime"))
                    .first {
                        // Taking care of the episode 2 item
                        ($0.episode...max($0.episode, $0.episode2 ?? 0))
                            .contains(episodeNumber)
                    } .tryUnwrap(.responseError("This episode does not exist"))
            }
        }
    }
}
