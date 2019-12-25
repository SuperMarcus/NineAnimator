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

extension NASourceAnimeDao {
    private static let animeAttributeMatchingExpression = try! NSRegularExpression(
        pattern: "<b>([^<:]+):?<\\/b>(?:<br\\s*\\/?>\\s*)?([^<]+)",
        options: [ .caseInsensitive ]
    )
    
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        return request(browseUrl: link.link).then {
            responseContent in
            let bowl = try SwiftSoup.parse(responseContent)
            
            // Reconstruct Anime Link
            let animeInfoContainer = try bowl.select("div.animeinfo-div")
            let animeArtworkPath = try animeInfoContainer
                .select(".animeinfo-poster img")
                .attr("data-src")
            let animeArtworkUrl = URL(
                string: animeArtworkPath,
                relativeTo: self.endpointURL
            ) ?? link.image
            let animeTitle = try animeInfoContainer
                .select(".animeinfo-div h2>b")
                .first()?
                .ownText() ?? link.title
            let reconstructedAnimeLink = AnimeLink(
                title: animeTitle,
                link: link.link,
                image: animeArtworkUrl,
                source: self
            )
            
            // Retrieve Episodes
            let episodeContainers = try bowl.select("#eps div.list-group a.animeinfo-content")
            let episodeList = try episodeContainers.reduce(into: [
                (
                    path: String,
                    name: String,
                    rawName: String,
                    fullName: String?,
                    epNumber: Int?,
                    airDate: String?
                )
            ]()) { results, current in
                let path = try current.attr("href")
                let airDate = try current.select("p.pull-right").first()?.ownText()
                let nameRaw = try current.select("p.list-group-item-heading>b")
                    .text()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let name: String = {
                    var nameComponents = nameRaw.components(separatedBy: "Episode")
                    if nameComponents.count > 1 {
                        let epNumberComponent = nameComponents
                            .removeLast()
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let epNameComponent = nameComponents
                            .joined(separator: "Episode")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return "\(epNumberComponent) - \(epNameComponent)"
                    } else { return nameRaw }
                }()
                let episodeNumber: Int? = {
                    if let episodeNumberComponent = name.split(separator: " ").first {
                        return Int(episodeNumberComponent)
                    }
                    return nil
                }()
                
                var fullName: String?
                
                if let episodeNameContainer = try current.select("p.list-group-item-text").first() {
                    fullName = episodeNameContainer.ownText()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                results.append((path, name, nameRaw, fullName, episodeNumber, airDate))
            }
            let serverMap = NASourceAnimeDao.knownServerMap.mapValues { $0.name }
            let episodesMap = serverMap.keys.map {
                serverIdentifier in (serverIdentifier, episodeList.map {
                    episodeInfo -> (EpisodeLink, Anime.AdditionalEpisodeLinkInformation) in
                    let ep = EpisodeLink(
                        identifier: "\(serverIdentifier)|\(episodeInfo.path)",
                        name: episodeInfo.name,
                        server: serverIdentifier,
                        parent: reconstructedAnimeLink
                    )
                    let info = Anime.AdditionalEpisodeLinkInformation(
                        parent: ep,
                        synopsis: episodeInfo.rawName,
                        airDate: episodeInfo.airDate,
                        episodeNumber: episodeInfo.epNumber,
                        title: episodeInfo.fullName
                    )
                    return (ep, info)
                })
            }
            let episodeLinks = Dictionary(
                uniqueKeysWithValues: episodesMap.map {
                    ($0.0, $0.1.map { $0.0 })
                }
            )
            let episodeAttributes = Dictionary(
                uniqueKeysWithValues: episodesMap.flatMap {
                    $0.1.map { ($0.0, $0.1) }
                }
            )
            
            // Parsing Anime Information
            var additionalAnimeAttributes = [Anime.AttributeKey: Any]()
            var animeSynopsis = ""
            var animeAliases = ""
            let attributeItemMatches = NASourceAnimeDao
                .animeAttributeMatchingExpression
                .matches(in: responseContent)
            
            for match in attributeItemMatches {
                let attributeKey = responseContent[match.range(at: 1)]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let attributeValue = responseContent[match.range(at: 2)]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                switch attributeKey {
                case "year":
                    additionalAnimeAttributes[.airDate] = attributeValue
                case "description":
                    animeSynopsis = attributeValue
                case "alternative":
                    animeAliases = attributeValue.replacingOccurrences(
                        of: ",",
                        with: ";"
                    )
                default: break // Unknown key
                }
            }
            
            return Anime(
                reconstructedAnimeLink,
                alias: animeAliases,
                additionalAttributes: additionalAnimeAttributes,
                description: animeSynopsis,
                on: serverMap,
                episodes: episodeLinks,
                episodesAttributes: episodeAttributes
            )
        }
    }
}
