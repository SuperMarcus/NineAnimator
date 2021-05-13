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

extension NASourceMonosChinos {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager.request(
            url: link.link,
            handling: .browsing
        ) .responseString.then {
            responseContent -> Anime in
            let bowl = try SwiftSoup.parse(responseContent)
            let animeTitle = try bowl.select("header > .row > div > h1.Title").text()
            
            let animeArtworkUrl = URL(
                string: try bowl.select("header > .row > div:first-child > .Image > figure > img").attr("src")
            ) ?? link.image
            let reconstructedAnimeLink = AnimeLink(
                title: animeTitle,
                link: link.link,
                image: animeArtworkUrl,
                source: self
            )
            
            // Obtain the list of episodes
            let episodeList = try bowl.select(".SerieCaps > a").compactMap {
                episodeElement -> (identifier: String, episodeName: String) in
                let episodeIdentifier = try episodeElement.attr("href")
                let episodeName = try episodeElement.text()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (episodeIdentifier, episodeName)
            }
            
            if episodeList.isEmpty {
                throw NineAnimatorError.responseError("No episode found for this anime")
            }
            
            // Collection of episodes
            var episodeCollection = Anime.EpisodesCollection()
            var episodeAttributes = [EpisodeLink: Anime.AdditionalEpisodeLinkInformation]()
            
            for (serverIdentifier, _) in NASourceMonosChinos.knownServers {
                var currentCollection = [EpisodeLink]()
                
                for (episodeIdentifier, episodeName) in episodeList {
                    var conventionalEpisodeName = episodeName
                    
                    let matchingRegex = try NSRegularExpression(
                        pattern: "(\\d+)\\sSub|Latino\\s(\\d+)",
                        options: [.caseInsensitive]
                    )
                    let episodeNumberMatch = try matchingRegex
                        .firstMatch(in: episodeName)
                        .tryUnwrap()
                        .firstMatchingGroup
                        .tryUnwrap()
                    let inferredEpisodeNumber = Int(episodeNumberMatch)
                    
                    if let eNumber = inferredEpisodeNumber {
                        conventionalEpisodeName = "\(eNumber) - \(episodeName)"
                    }
                    
                    let currentEpisodeLink = EpisodeLink(
                        identifier: episodeIdentifier,
                        name: conventionalEpisodeName,
                        server: serverIdentifier,
                        parent: reconstructedAnimeLink
                    )
                    currentCollection.append(currentEpisodeLink)
                    
                    let currentEpisodeAttribute = Anime.AdditionalEpisodeLinkInformation(
                        parent: currentEpisodeLink,
                        synopsis: nil,
                        airDate: nil,
                        season: nil,
                        episodeNumber: inferredEpisodeNumber,
                        title: episodeName
                    )
                    episodeAttributes[currentEpisodeLink] = currentEpisodeAttribute
                }
                
                episodeCollection[serverIdentifier] = currentCollection.reversed()
            }
            
            // Information
            let animeSynopsis = try bowl
                .select("header > .row > div > .Description > p")
                .text()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Attributes
            var additionalAnimeAttributes = [Anime.AttributeKey: Any]()
            let date = try bowl
                .select("header > .row > div > .after-title")
                .text()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " ")
            
            additionalAnimeAttributes[.airDate] = date[1]
            
            return Anime(
                reconstructedAnimeLink,
                alias: "",
                additionalAttributes: additionalAnimeAttributes,
                description: animeSynopsis,
                on: NASourceMonosChinos.knownServers,
                episodes: episodeCollection,
                episodesAttributes: episodeAttributes
            )
        }
    }
}
