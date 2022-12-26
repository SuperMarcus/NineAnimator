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

extension NASourceAnimeUltima {
    // The intermiddiate information for constructing the anime and episode links
    
    struct ConstructingEpisodeInformation {
        var name: String?
        var number: String
        var airDate: String?
        var url: URL
    }
    
    struct ConstructingAnimeInformation {
        var attributes: [Anime.AttributeKey: Any]
        var episodes: [ConstructingEpisodeInformation]
        var reconstructedLink: AnimeLink
        var synopsis: String
        var alias: String
    }
}

extension NASourceAnimeUltima {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager.request(url: link.link, handling: .browsing)
            .responseString
            .then {
                responseContent -> ConstructingAnimeInformation in
                let bowl = try SwiftSoup.parse(responseContent)
                let documentHead = try some(bowl.head(), or: .responseError("Response does not have a head section"))
                
                // Store all additional properties
                var animeAdditionalAttributes = [Anime.AttributeKey: Any]()
                
                // Find the anime info in the head element
                let contextScriptContainer = try documentHead
                    .select("script")
                    .first { try $0.attr("type").lowercased() == "application/ld+json" }
                let contextJsonData = try some(
                    contextScriptContainer?.data().data(using: .utf8),
                    or: .responseError("Cannot gather all necessary information for this anime")
                )
                let animeInfo = try some(
                    try JSONSerialization.jsonObject(with: contextJsonData, options: []) as? NSDictionary,
                    or: .responseError("Response is encoded incorrectly")
                )
                
                // Obtain the artwork url
                let artworkUrlString = try some(animeInfo["image"] as? String, or: .responseError("Cannot find an artwork of this anime"))
                let artwrokUrl = try some(URL(string: artworkUrlString), or: .urlError)
                
                // Obtain the synopsis of the anime
                let animeSynopsis: String
                if let reportedSynopsis = animeInfo["description"] as? String {
                    animeSynopsis = reportedSynopsis
                } else { animeSynopsis = "No synopsis found for this anime." }
                
                // Obtain anime title
                let animeTitleContainer = try bowl.select("h1.title")
                let animeTitle = animeTitleContainer.first()?.ownText() ?? link.title
                
                // Retrieve the release year
                if let animeReleaseYear = try? animeTitleContainer
                        .select("span.year")
                        .text()
                        .split(separator: " ")
                        .first?
                        .description {
                    animeAdditionalAttributes[.airDate] = animeReleaseYear
                }
                
                // Aliases of the anime
                let animeAlias = (try? bowl.select("small").first()?.ownText()) ?? ""
                
                // Reconstruct the anime link
                let reconstructedAnimeLink = AnimeLink(
                    title: animeTitle,
                    link: link.link,
                    image: artwrokUrl,
                    source: self
                )
                
                // Parse episode list
                var episodeListEntry = [NSDictionary]()
                
                if let episodeListEntryRaw = animeInfo["episodes"] as? [NSDictionary] {
                    episodeListEntry = episodeListEntryRaw
                } else if let potentialActionList = animeInfo["potentialAction"] as? NSDictionary,
                    (potentialActionList["@type"] as? String) == "WatchAction",
                    let targetEpisodeUrlString = potentialActionList["target"] as? String {
                    // Assemble an episode from the watch action list
                    let assemblingRawEpisode = NSMutableDictionary()
                    assemblingRawEpisode["url"] = targetEpisodeUrlString
                    assemblingRawEpisode["name"] = animeTitle
                    
                    // Present the type of the anime in place of the name
                    if let animeType = animeInfo["@type"] as? String {
                        assemblingRawEpisode["name"] = animeType
                    }

                    episodeListEntry.append(assemblingRawEpisode)
                }
                
                var listOfEpisodes = [ConstructingEpisodeInformation]()
                
                // Iterate through the episode list
                for episodeEntry in episodeListEntry {
                    var episodeName = episodeEntry["name"] as? String
                    var episodeAirDate: String?
                    let episodeNumber = (episodeEntry["episodeNumber"] as? String) ?? "1"
                    
                    // Process the episode name -- sometimes an "Episode XX" is appended
                    // to the name returned by the server. This process removes it.
                    if let preprocessingEpisodeName = episodeName {
                        let possibleSuffix = "episode \(episodeNumber)"
                        
                        // Check if the name has the suffix
                        if preprocessingEpisodeName.lowercased().hasSuffix(possibleSuffix) {
                            episodeName?.removeLast(possibleSuffix.count)
                            episodeName = episodeName?.trimmingCharacters(in: .whitespaces)
                        }
                        
                        // Set the episode name to nil if it becomes empty after being processed
                        if episodeName?.isEmpty == true {
                            episodeName = nil
                        }
                        
                        // Set the episode name to nil if the name is the title
                        // This means the title of this episode has not been added yet
                        if episodeName == reconstructedAnimeLink.title {
                            episodeName = nil
                        }
                    }
                    
                    // Present the date published as additional episode information
                    if let datePublished = (episodeEntry["datePublished"] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                        !datePublished.isEmpty {
                        let dateParser = DateFormatter()
                        dateParser.dateFormat = "yyyy-MM-dd"
                        
                        // If the date is formattable
                        if let date = dateParser.date(from: datePublished) {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .long
                            formatter.timeStyle = .none
                            episodeAirDate = formatter.string(from: date)
                        } else { episodeAirDate = datePublished }
                    }
                    
                    // The most important step: retrieve the url
                    guard let episodeUrlString = episodeEntry["url"] as? String,
                        let episodeUrl = URL(string: episodeUrlString) else {
                        Log.info("Cannot parse an episode for this anime. Continuing with the next one.")
                        continue
                    }
                    
                    // Enqueue the episode information
                    listOfEpisodes.append(.init(
                        name: episodeName,
                        number: episodeNumber,
                        airDate: episodeAirDate,
                        url: episodeUrl
                    ))
                }
                
                // Check to make sure that there is at least one episode
                if listOfEpisodes.isEmpty {
                    throw NineAnimatorError.responseError("No episodes found for this anime.")
                }
                
                return ConstructingAnimeInformation(
                    attributes: animeAdditionalAttributes,
                    episodes: listOfEpisodes,
                    reconstructedLink: reconstructedAnimeLink,
                    synopsis: animeSynopsis,
                    alias: animeAlias
                )
            } .thenPromise {
                information -> NineAnimatorPromise<(ConstructingAnimeInformation, EpisodePageInformation)> in
                // Request the server list from the first episode
                let firstEpisodeInformation = information.episodes.first!
                return self
                    .pageInformation(for: firstEpisodeInformation.url)
                    .then { (information, $0) }
            } .then {
                information, page in
                // Obtain the list of mirrors
                var availableServers = [Anime.ServerIdentifier: String]()
                page.availableMirrors.forEach { availableServers[$0.value] = $0.value }
                
                // Compile the completed episode list
                var episodeInformationMap = [EpisodeLink: Anime.AdditionalEpisodeLinkInformation]()
                let finalEpisodeList: Anime.EpisodesCollection = availableServers.mapValues {
                    serverName in information.episodes.map {
                        episodeInformation in
                        let finalEpisodeTitle: String = {
                            let prefix = episodeInformation.number
                            if let name = episodeInformation.name {
                                return "\(prefix) - \(name)"
                            } else { return prefix }
                        }()
                        
                        // Construct the episode link
                        let episodeLink = EpisodeLink(
                            identifier: episodeInformation.url.pathComponents[3],
                            name: finalEpisodeTitle,
                            server: serverName,
                            parent: information.reconstructedLink
                        )
                        
                        // Store the additional episode information
                        episodeInformationMap[episodeLink] = Anime.AdditionalEpisodeLinkInformation(
                            parent: episodeLink,
                            airDate: episodeInformation.airDate,
                            episodeNumber: Int(episodeInformation.number),
                            title: episodeInformation.name
                        )
                        
                        return episodeLink
                    }
                }
                
                // Construct the anime object
                return Anime(
                    information.reconstructedLink,
                    alias: information.alias,
                    additionalAttributes: information.attributes,
                    description: information.synopsis,
                    on: availableServers,
                    episodes: finalEpisodeList,
                    episodesAttributes: episodeInformationMap
                )
            }
    }
}
