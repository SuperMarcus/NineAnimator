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

struct AnimeTwistListedAnime {
    let identifier: Int
    let title: String
    let alternativeTitle: String
    let slug: String
    let createdDate: Date
    let updatedDate: Date
    let isOngoing: Bool
    let kitsuIdentifier: Int?
}

extension NASourceAnimeTwist {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        let slug = link.link.lastPathComponent
        return listedAnimePromise.then {
            $0.first { $0.slug == slug }
        } .thenPromise {
            info in
            self.requestDescriptor().then { ($0, info) }
        } .thenPromise {
            sourceDescriptor, info in
            self.requestManager.request(
                "/api/anime/\(info.slug)/sources",
                handling: .ajax,
                headers: [ "x-access-token": "0df14814b9e590a1f26d3071a4ed7974" ]
            )
            .responseString
            .then { (sourceDescriptor, info, $0) }
        } .then {
            sourceDescriptor, info, sourceListString in
            guard let sourceListData = sourceListString.data(using: .utf8),
                let sourceList = try JSONSerialization.jsonObject(with: sourceListData, options: []) as? [NSDictionary] else {
                throw NineAnimatorError.providerError("Unable to fetch sources list")
            }
            let reconstructedLink = AnimeLink(
                title: link.title,
                link: link.link,
                image: info.artworkUrl,
                source: self
            )
            // Twist Uses different cdn for ongoing animes
            let availableCDN = info.isOngoing ?  sourceDescriptor.ongoingAnimeCDN : sourceDescriptor.regularAnimeCDN
            
            let episodesList = sourceList.compactMap {
                episode -> (EpisodeLink, String)? in
                guard let identifier = episode["id"] as? Int,
                    let episodeNumber = episode["number"] as? Int,
                    let encryptedSource = episode["source"] as? String else { return nil }
                return (EpisodeLink(
                    identifier: "\(identifier)",
                    name: "\(episodeNumber)",
                    server: "twist.moe",
                    parent: reconstructedLink
                ), encryptedSource)
            }
            // Construct anime object
            return Anime(
                reconstructedLink,
                alias: info.alternativeTitle,
                additionalAttributes: [
                    "twist.source": Dictionary(uniqueKeysWithValues: episodesList.map {
                        ($0.0, $0.1)
                    }),
                    "availableCDN": availableCDN
                ],
                description: "No description available on Anime Twist.",
                on: ["twist.moe": "Anime Twist"],
                episodes: ["twist.moe": episodesList.map { $0.0 }]
            )
        }
    }
    
    func anime(_ animeInfo: AnimeTwistListedAnime) -> AnimeLink {
        AnimeLink(
            title: animeInfo.title,
            link: endpointURL.appendingPathComponent("/a/\(animeInfo.slug)"),
            image: animeInfo.artworkUrl,
            source: self
        )
    }
}

extension AnimeTwistListedAnime {
    var artworkUrl: URL {
        let defaultArtwork = NineAnimator.placeholderArtworkUrl
        if let kitsuId = kitsuIdentifier {
            return URL(string: "https://media.kitsu.io/anime/poster_images/\(kitsuId)/large.jpg") ??
                defaultArtwork
        }
        return defaultArtwork
    }
}
