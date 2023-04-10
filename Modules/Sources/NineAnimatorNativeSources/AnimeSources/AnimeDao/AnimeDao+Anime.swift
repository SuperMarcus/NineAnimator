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

extension NASourceAnimeDao {
    private static let animeAttributeMatchingExpression = try! NSRegularExpression(
        pattern: "<b>([^<:]+):?<\\/b>(?:<br\\s*\\/?>\\s*)?([^<]+)",
        options: [ .caseInsensitive ]
    )
    
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        NineAnimatorPromise.firstly {
            var animePageLinkBuilder = try URLComponents(
                url: link.link,
                resolvingAgainstBaseURL: true
            ).tryUnwrap()
            
            if let linkHost = animePageLinkBuilder.host, self.deprecatedHosts.contains(linkHost) {
                animePageLinkBuilder.host = self.endpointURL.host
            }
            
            return animePageLinkBuilder.url
        } .thenPromise {
            animePageUrl in self.requestManager.request(
                url: animePageUrl,
                handling: .browsing
            ) .responseString
        } .then {
            responseContent in
            let bowl = try SwiftSoup.parse(responseContent)
            
            // Reconstruct Anime Link
            let animeInfoContainer = try bowl.select("._animeinfo")
            let animeArtworkPath = try animeInfoContainer
                .select(".main-poster")
                .attr("data-src")
            let animeArtworkUrl = URL(
                string: animeArtworkPath,
                relativeTo: self.endpointURL
            ) ?? link.image
            let animeTitle = try animeInfoContainer
                .select("h2>b")
                .first()?
                .ownText() ?? link.title
            let reconstructedAnimeLink = AnimeLink(
                title: animeTitle,
                link: link.link,
                image: animeArtworkUrl,
                source: self
            )
            
            // Retrieve Episodes
            let episodeContainers = try bowl.select("#episodes-tab-pane .episodelist")
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
                let path = try current.select("a").attr("href")
                let airDate = try current.select(".card-body .animeinfo .badge.date").text()
                let nameRaw = try current.select("span.animename")
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
                
                if let episodeNameContainer = try current.select("div.animetitle span").first() {
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
                        identifier: "\(serverIdentifier)|\(episodeInfo.path)|\(serverIdentifier)",
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
            let animeSynopsis = try animeInfoContainer.select(".d-sm-block").text()
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
