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
import NineAnimatorCommon
import SwiftSoup

extension NASourceZoroAnime {
    fileprivate struct EpisodesResponse: Decodable {
        let continueWatch: Bool?
        let html: String
        let status: Bool
        let totalItems: Int
    }
    
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        NineAnimatorPromise<String>.firstly {
            // Extract Anime ID From URL
            let animeID = link.link.lastPathComponent.split(separator: "-", omittingEmptySubsequences: false).last ?? ""
            return String(animeID)
        } .thenPromise {
            animeID in
            // Request Anime Information
            self.requestManager.request(
                url: link.link,
                handling: .browsing
            ) .responseBowl.then { (animeID, $0) }
        } .thenPromise {
            animeId, animeDetailsBowl in
            // Request Episode Information
            self.requestManager.request(
                url: self.ajaxEndpoint.appendingPathComponent("v2/episode/list/\(animeId)"),
                handling: .ajax
            ) .responseDecodable(type: EpisodesResponse.self).then { (animeDetailsBowl, $0) }
        } .then {
            animeDetailsBowl, episodesResponse in

            let animeTitle = try animeDetailsBowl.select("h2.film-name").text()
            let animeCoverURL = try URL(
                protocolRelativeString: animeDetailsBowl.select(".film-poster > img.film-poster-img").attr("src"),
                relativeTo: self.endpointURL
            ).tryUnwrap(.urlError)
            let animeSynopsis = try animeDetailsBowl.select(".film-description > div").text()
            let animeSynonyms = try animeDetailsBowl.select(".anisc-info > .item")[safe: 2]!.select("span.name").text()
            
            // Reconstruct AnimeLink
            let reconstructedAnimeLink = AnimeLink(
                title: animeTitle,
                link: link.link,
                image: animeCoverURL,
                source: self
            )
            
            // Set Anime Air Date
            var additionalAnimeAttributes = [Anime.AttributeKey: Any]()
            additionalAnimeAttributes[.airDate] = try animeDetailsBowl.select(".anisc-info > .item")[safe: 3]!.select("span.name").text()
            
            var availableServerList = NASourceZoroAnime.knownServers
            // Check if anime has dubbed episodes, also incorrectly assume each every supported server is available
            let animeStats = try animeDetailsBowl.select(".film-stats > span > .tick-dub").text()
            if animeStats.localizedCaseInsensitiveContains("dub") {
                let knownDubbedServers = [
                    "VidStreaming (Dub)": "VidStreaming (Dub)", // Uses rapidcloud parser
                    "Vidcloud (Dub)": "Vidcloud (Dub)",         // Uses rapidcloud parser
                    "Streamsb (Dub)": "Streamsb (Dub)",
                    "Streamtape (Dub)": "Streamtape (Dub)"
                ]
                
                availableServerList.merge(knownDubbedServers) { $1 }
            }
            
            let episodesBowl = try SwiftSoup.parse(episodesResponse.html)
            let episodeList = try episodesBowl.select(".ss-list > .ep-item").compactMap {
                episodeElement -> (identifier: String, episodeNumber: String, episodeTitle: String) in
                let episodeIdentifier = try episodeElement.attr("data-id")
                let episodeNumber = try episodeElement.attr("data-number")
                let episodeTitle = try episodeElement.attr("title")
                
                return (episodeIdentifier, episodeNumber, episodeTitle)
            }
            
            if episodeList.isEmpty {
                throw NineAnimatorError.responseError("No episodes found for this anime")
            }
            
            // Collection of episodes
            var episodeCollection = Anime.EpisodesCollection()
            var episodeInfo = [EpisodeLink: Anime.AdditionalEpisodeLinkInformation]()

            // We incorrectly assume each server contains every episode
            for (serverIdentifier, _) in availableServerList {
                var currentCollection = [EpisodeLink]()

                for (episodeIdentifier, episodeName, episodeTitle) in episodeList {
                    let currentEpisodeLink = EpisodeLink(
                        identifier: episodeIdentifier,
                        name: episodeName,
                        server: serverIdentifier,
                        parent: reconstructedAnimeLink
                    )
                    
                    episodeInfo[currentEpisodeLink] = Anime.AdditionalEpisodeLinkInformation(
                        parent: currentEpisodeLink,
                        episodeNumber: Int(episodeName),
                        title: episodeTitle
                    )
                    
                    currentCollection.append(currentEpisodeLink)
                }

                episodeCollection[serverIdentifier] = currentCollection
            }

            return Anime(
                reconstructedAnimeLink,
                alias: animeSynonyms,
                additionalAttributes: additionalAnimeAttributes,
                description: animeSynopsis,
                on: availableServerList,
                episodes: episodeCollection,
                episodesAttributes: episodeInfo
            )
        }
    }
}
