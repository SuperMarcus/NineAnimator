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
import SwiftSoup

// swiftlint:disable closure_end_indentation
extension NASourceGogoAnime {
    fileprivate static let animeIdentifierRegex =
        try! NSRegularExpression(pattern: "id\\s+=\\s+(\\d+)", options: [])
    
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        anime(url: link.link)
    }
    
    func anime(url: URL) -> NineAnimatorPromise<Anime> {
        request(browseUrl: url)
            .thenPromise { content -> NineAnimatorPromise<(String, String)> in
                guard let animeIdentifier = NASourceGogoAnime
                    .animeIdentifierRegex
                    .firstMatch(in: content)?
                    .firstMatchingGroup else {
                        throw NineAnimatorError.responseError("Cannot identify the anime")
                }
                
                let episodeInformationBaseUrl = self
                    .ajaxEndpoint
                    .appendingPathComponent("/ajax/load-list-episode")
                var episodeInformationUrl = URLComponents(
                    url: episodeInformationBaseUrl,
                    resolvingAgainstBaseURL: true
                )
                
                // It looks like these are the only information that matters
                episodeInformationUrl?.queryItems = [
                    .init(name: "ep_start", value: "0"),
                    .init(name: "ep_end", value: "9999"),
                    .init(name: "id", value: animeIdentifier)
                ]
                
                // Generate the final url
                guard let generatedUrl = episodeInformationUrl?.url else {
                    throw NineAnimatorError.urlError
                }
                
                return self
                    .request(ajaxUrlString: generatedUrl)
                    .then { ($0, content) }
            } .thenPromise {
                episodeListContent, animeContent
                -> NineAnimatorPromise<(String, [String: String], NAGogoAnimeEpisodeInformation)> in
                // Parse the two contents
                let episodeListBowl = try SwiftSoup.parse(episodeListContent)
                
                // First, retrieve the list of episodes
                let episodeListContainer = try episodeListBowl.select("a")
                let episodes = try episodeListContainer.compactMap {
                    episodeContainer -> (String, String) in
                    // Remove the "EP" thing
                    try episodeContainer.select("div.name>span").remove()
                    let episodePath =
                        try episodeContainer.attr("href").trimmingCharacters(in: .whitespaces)
                    return (episodePath, try episodeContainer.text().trimmingCharacters(in: .whitespaces))
                }
                
                // Make sure there is at least one episode
                guard let firstEpisode = episodes.first else {
                    throw NineAnimatorError.responseError("No episode found for this anime")
                }
                
                // Request the servers available on the first episode to synthesis the Anime struct
                return self.episodeInformation(for: firstEpisode.0)
                    .then { (animeContent, Dictionary(uniqueKeysWithValues: episodes), $0) }
            } .then {
                animeContent, episodes, firstEpisodeInformation in
                let animeBowl = try SwiftSoup.parse(animeContent)
                
                var animeSynopsis: String = "No description"
                var releaseYear: String = "Unknown Year"
                var animeStatus: String = "Unknown Status"
                
                // Then, retrieve anime information container
                let animeAttributesContainer = try animeBowl.select("div.anime_info_body_bg")
                
                // Retrieve the list of attributes
                try animeAttributesContainer.select("p.type").forEach {
                    animeAttribute in
                    let animeAttributeKeyElement = try animeAttribute.select("span")
                    let animeAttributeKeyString =
                        try animeAttributeKeyElement.text().trimmingCharacters(in: .whitespaces)
                    try animeAttributeKeyElement.remove()
                    
                    switch animeAttributeKeyString.lowercased() {
                    case "plot summary:": animeSynopsis = try animeAttribute.text()
                    case "released:": releaseYear = try animeAttribute.text()
                    case "status:": animeStatus = try animeAttribute.text()
                    default: break
                    }
                }
                
                // Retrieve the title of the anime
                let animeTitle = try animeAttributesContainer.select("h1").text()
                
                // Retrieve the artwork
                guard let firstImg = try animeAttributesContainer.select("img").first(),
                    let animeArtworkUrl = URL(string: try firstImg.attr("src")) else {
                    throw NineAnimatorError.responseError("No artwork found for anime")
                }
                
                // Reconstruct the anime link
                let reconstructedAnimeLink = AnimeLink(
                    title: animeTitle,
                    link: url,
                    image: animeArtworkUrl,
                    source: self
                )
                
                // Retrieve the list of servers from the first episode information
                let serverIdentifiers = firstEpisodeInformation.sources.map { $0.0 }
                
                // And, finally, construct the Anime struct
                return Anime(
                    reconstructedAnimeLink,
                    alias: "",
                    additionalAttributes: [
                        .airDate: "\(releaseYear) - \(animeStatus)"
                    ],
                    description: animeSynopsis,
                    on: Dictionary(uniqueKeysWithValues:
                        firstEpisodeInformation.sources.map { ($0.0, $0.0) }
                    ), // Servers: using name as identifier
                    episodes: Dictionary(uniqueKeysWithValues:
                        serverIdentifiers.map {
                            serverIdentifier in
                            (serverIdentifier, episodes.map {
                                EpisodeLink(
                                    identifier: $0.0,
                                    name: $0.1,
                                    server: serverIdentifier,
                                    parent: reconstructedAnimeLink
                                )
                            } .sorted {
                                (l: EpisodeLink, r: EpisodeLink) in
                                guard let lFirst = l.name.split(separator: " ").first,
                                    let rFirst = r.name.split(separator: " ").first else {
                                        return l.name < r.name
                                }
                                return (Int(String(lFirst)) ?? 0) < (Int(String(rFirst)) ?? 1)
                            })
                        }
                    ),
                    episodesAttributes: [:]
                )
            }
    }
}
