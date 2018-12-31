//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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

extension NineAnimeSource {
    static let animeAliasRegex = try! NSRegularExpression(pattern: "<p class=\"alias\">([^<]+)", options: .caseInsensitive)
    static let animeAttributesRegex = try! NSRegularExpression(pattern: "<dt>([^<:]+):*<\\/dt>\\s+<dd>([^<]+)")
    static let animeResourceTagsRegex = try! NSRegularExpression(pattern: "<div id=\"servers-container\" data-id=\"([^\"]+)\" data-bind-api=\"#player\" data-epid=\"([^\"]*)\" data-epname=\"[^\"]*\"\\s*>", options: .caseInsensitive)
    static let animeServerListRegex = try! NSRegularExpression(pattern: "<span\\s+class=[^d]+data-name=\"([^\"]+)\">([^<]+)", options: .caseInsensitive)
    
    func anime(from link: AnimeLink, _ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask? {
        let taskTracker = NineAnimatorMultistepAsyncTask()
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
            let matches = NineAnimeSource.animeAliasRegex.matches(
                in: page, range: page.matchingRange
            )
            return matches.isEmpty ? nil : page[matches[0].range(at: 1)]
        }()
        
        let animeAttributes: [(name: String, value: String)] = {
            let matches = NineAnimeSource.animeAttributesRegex.matches(
                in: page,
                range: page.matchingRange
            )
            return matches
                .filter { page[$0.range(at: 2)].isEmpty }
                .map { (page[$0.range(at: 1)], page[$0.range(at: 2)]) }
        }()
        
        let animeResourceTags: (id: String, episode: String) = {
            let matches = NineAnimeSource.animeResourceTagsRegex.matches(
                in: page, range: page.matchingRange
            )
            return (page[matches[0].range(at: 1)], page[matches[0].range(at: 2)])
        }()
        
        let animeDescription = (try? bowl.select("div.desc").text()) ?? "No description"
        
        let ajaxHeaders: [String: String] = ["Referer": link.link.absoluteString]
        
        debugPrint("Info: Retrived information for \(link)")
        debugPrint("- Alias: \(alias ?? "None")")
        debugPrint("- Description: \(animeDescription)")
        debugPrint("- Attributes: \(animeAttributes)")
        debugPrint("- Resource Identifiers: ID=\(animeResourceTags.id), EPISODE=\(animeResourceTags.episode)")
        
        return request(ajax: "/ajax/film/servers/\(animeResourceTags.id)", with: ajaxHeaders) {
            response, error in
            guard let responseJson = response else {
                return handler(nil, error)
            }
            
            guard let htmlList = responseJson["html"] as? String else {
                debugPrint("Error: Invalid response")
                return handler(nil, NineAnimatorError.responseError(
                    "unable to retrive episode list from responses"
                ))
            }
            
            let matches = NineAnimeSource.animeServerListRegex.matches(
                in: htmlList, range: htmlList.matchingRange
            )
            
            let animeServers: [Anime.ServerIdentifier: String] = Dictionary(
                matches.map { match in
                    (htmlList[match.range(at: 1)], htmlList[match.range(at: 2)])
                }, uniquingKeysWith: { _, new in new }
            )
            
            var animeEpisodes = [Anime.ServerIdentifier: Anime.EpisodeLinksCollection]()
            
            debugPrint("Info: \(animeServers.count) servers found for this anime.")
            
            do {
                let soup = try SwiftSoup.parse(htmlList)
                
                for server in try soup.select("div.server") {
                    let serverIdentifier = try server.attr("data-id")
                    animeEpisodes[serverIdentifier] = try server.select("li>a").map {
                        EpisodeLink(
                            identifier: try $0.attr("data-id"),
                            name: try $0.text(),
                            server: serverIdentifier,
                            parent: link)
                    }
                    debugPrint("Info: \(animeEpisodes[serverIdentifier]!.count) episodes found on server \(serverIdentifier)")
                }
                
                handler(Anime(link,
                              description: animeDescription,
                              on: animeServers,
                              episodes: animeEpisodes), nil)
            } catch {
                debugPrint("Unable to parse servers and episodes")
                handler(nil, error)
            }
        }
    }
}
