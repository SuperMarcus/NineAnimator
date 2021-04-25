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

import Alamofire
import Foundation

extension NASourceArrayanime {
    fileprivate struct AnimeResponse: Decodable {
        let results: [AnimeEntry]
    }
    
    fileprivate struct AnimeEntry: Decodable {
        let Othername: String
        let genres: String
        let image: String
        let relased: String
        let status: String
        let summary: String
        let title: String
        let totalepisode: String
        let type: String
    }

    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        NineAnimatorPromise<String>.firstly {
            // Extract Anime ID From URL
            let animeID = link.link.lastPathComponent
            guard !animeID.isEmpty else { throw NineAnimatorError.urlError }
            return animeID
        } .thenPromise {
            animeID in
            self.requestManager.request(
                url: self.vercelEndpoint.appendingPathComponent("/details/\(animeID)"),
                handling: .ajax
            ) .responseDecodable(type: AnimeResponse.self)
              .then { ($0, animeID) }
        } .then {
            animeResponse, animeID in
            let animeDetails = try animeResponse.results.map {
                animeEntry -> Anime in
                
                let encodedImage = try animeEntry.image
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                .tryUnwrap(.urlError)

                // Parsing Anime Information
                var additionalAnimeAttributes = [Anime.AttributeKey: Any]()
                additionalAnimeAttributes[.airDate] = animeEntry.relased
                
                // Reconstruct AnimeLink
                let reconstructedAnimeLink = AnimeLink(
                    title: animeEntry.title,
                    link: link.link,
                    image: try URL(
                        protocolRelativeString: encodedImage,
                        relativeTo: link.link
                    ).tryUnwrap(.urlError),
                    source: self
                )
                    
                // Add each episode to every server
                var episodeCollection = Anime.EpisodesCollection()
                
                let totalEpisode = Int(animeEntry.totalepisode) ?? 0
                
                if totalEpisode > 0 {
                    // We assume each server contains every episode
                    for (serverIdentifier, _) in NASourceArrayanime.knownServers {
                        episodeCollection[serverIdentifier] = (1...totalEpisode).map { episodeNo in
                            EpisodeLink(
                                identifier: "\(animeID)-\(episodeNo)",
                                name: "\(episodeNo)",
                                server: serverIdentifier,
                                parent: reconstructedAnimeLink
                            )
                        }
                    }
                }
                
                return Anime(
                    reconstructedAnimeLink,
                    alias: animeEntry.Othername,
                    additionalAttributes: additionalAnimeAttributes,
                    description: animeEntry.summary,
                    on: NASourceArrayanime.knownServers,
                    episodes: episodeCollection
                )
            }
            return animeDetails.first
        }
    }
}
