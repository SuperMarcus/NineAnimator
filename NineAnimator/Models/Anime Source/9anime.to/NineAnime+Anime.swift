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
import SwiftSoup

extension NASourceNineAnime {
    static let animeAliasRegex = try! NSRegularExpression(pattern: "<p class=\"alias\">([^<]+)", options: .caseInsensitive)
    static let animeAttributesRegex = try! NSRegularExpression(pattern: "<dt>([^<:]+):*<\\/dt>\\s+<dd>([^<]+)")
    static let animeServerListRegex = try! NSRegularExpression(pattern: "<span\\s+class=[^d]+data-name=\"([^\"]+)\">([^<]+)", options: .caseInsensitive)
    
    func anime(from link: AnimeLink, _ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask? {
//        handler(nil, NineAnimatorError.contentUnavailableError("9anime.to has been temporarily disabled."))
//        return nil
        let taskTracker = AsyncTaskContainer()
        taskTracker.add(request(browse: link.link, headers: [:]) {
            [weak taskTracker] response, error in
            // Return without trigger an error
            guard let taskTracker = taskTracker else { return }
            guard let response = response else {
                return handler(nil, error)
            }
            taskTracker.add(self.parseAnime(from: response, with: link, handler))
        })
        return taskTracker
    }
    
    func parseAnime(from page: String, with link: AnimeLink, _ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask? {
        let bowl = try! SwiftSoup.parse(page)
        
        let alias: String? = {
            let matches = NASourceNineAnime.animeAliasRegex.matches(
                in: page, range: page.matchingRange
            )
            return matches.isEmpty ? nil : page[matches[0].range(at: 1)]
        }()
        
        do {
            let serverContainerElement = try bowl.select("div#servers-container")
            
            let animeResourceTags = (
                id: try serverContainerElement.attr("data-id"),
                episode: try serverContainerElement.attr("data-epid")
            )
            
            let animeDescription = (try? bowl.select("div.desc").text()) ?? "No description"
            let animePosterURL = URL(string: try bowl.select("div.thumb>img").attr("src")) ?? link.image
            let animeAttributesRaw: [String: String] = {
                do {
                    let zippedSequence = zip(
                        try bowl.select("div.info>div.row dt").array().map { try $0.text() },
                        try bowl.select("div.info>div.row dd").array().map { try $0.text() }
                    )
                return Dictionary(uniqueKeysWithValues: zippedSequence)
                } catch { return [:] }
            }()
//            let animeAttributesString = animeAttributesRaw.map { "・ \($0.0) \($0.1)\n" }.joined()
            let animeTitle = try bowl.select(".info .title").text()
            let animeAlias = (try? bowl.select(".info .alias").text()) ?? ""
            
            var animeAttributes = [Anime.AttributeKey: Any]()
            
            for (key, value) in animeAttributesRaw {
                switch key.lowercased() {
                case "rating:":
                    let labels = value.split(separator: "/")
                    guard let ratingString = labels.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                        let rating = Float(String(ratingString)) else { continue }
                    animeAttributes[.rating] = rating
                    animeAttributes[.ratingScale] = Float(10.0)
                case "date aired:":
                    animeAttributes[.airDate] = value.trimmingCharacters(in: .whitespacesAndNewlines)
                default: continue
                }
            }
            
            let ajaxHeaders: [String: String] = ["Referer": link.link.absoluteString]
            
            let reconstructedLink = AnimeLink(
                title: animeTitle,
                link: link.link,
                image: animePosterURL,
                source: link.source
            )
            
            Log.info("Retrived information for %@", link)
            Log.debug("- Alias: %@", alias ?? "None")
            Log.debug("- Resource Identifiers: ID=%@, EPISODE=%@", animeResourceTags.id, animeResourceTags.episode)
            
            return signedRequest(
                ajax: "/ajax/film/servers/\(animeResourceTags.id)",
                with: ajaxHeaders
            ) { response, error in
                guard let responseJson = response else {
                    return handler(nil, error)
                }
                
                guard let htmlList = responseJson["html"] as? String else {
                    Log.error("Invalid response")
                    return handler(nil, NineAnimatorError.responseError(
                        "unable to retrieve episode list from responses"
                    ))
                }
                
                let matches = NASourceNineAnime.animeServerListRegex.matches(
                    in: htmlList, range: htmlList.matchingRange
                )
                
                let animeServers: [Anime.ServerIdentifier: String] = Dictionary(
                    matches.map { match in
                        (htmlList[match.range(at: 1)], htmlList[match.range(at: 2)])
                    }
                ) { _, new in new }
                    
                guard !animeServers.isEmpty else { return handler(nil, NineAnimatorError.responseError("No episodes found for this anime.")) }
                
                var animeEpisodes = [Anime.ServerIdentifier: Anime.EpisodeLinksCollection]()
                
                do {
                    let soup = try SwiftSoup.parse(htmlList)
                    
                    for server in try soup.select("div.server") {
                        let serverIdentifier = try server.attr("data-id")
                        animeEpisodes[serverIdentifier] = try server.select("li>a").map {
                            let dataIdentifier = try $0.attr("data-id")
                            let pathIdentifier = try $0.attr("href")
                            return EpisodeLink(
                                identifier: "\(dataIdentifier)|\(pathIdentifier)",
                                name: try $0.text(),
                                server: serverIdentifier,
                                parent: reconstructedLink
                            )
                        }
                    }
                    
                    // Reconstruct the AnimeLink so we get the correct URLs and titles
                    handler(Anime(reconstructedLink,
                                  alias: animeAlias,
                                  additionalAttributes: animeAttributes,
//                                  description: "\(animeAttributesString)\n\(animeDescription)",
                                  description: animeDescription,
                                  on: animeServers,
                                  episodes: animeEpisodes), nil)
                } catch {
                    Log.error("Unable to parse servers and episodes")
                    handler(nil, error)
                }
            }
        } catch {
            handler(nil, error)
        }
        return nil
    }
}
