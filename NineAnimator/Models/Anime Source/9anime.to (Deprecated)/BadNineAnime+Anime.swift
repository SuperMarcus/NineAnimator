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

extension NASourceNineAnimeOld {
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
        // Delegate to the new promise-based `_parseAnime(from:, with:)`
        _parseAnime(from: page, with: link).handle(handler)
    }
}

private extension NASourceNineAnimeOld {
    struct AnimeInitialPageInformation {
        var bowl: SwiftSoup.Document
        var reconstructedLink: AnimeLink
        var animeResourceTags: (id: String, episode: String)
        var attributes: [Anime.AttributeKey: Any]
        var alias: String
        var description: String
        
        var referer: String {
            animeResourceTags.episode.isEmpty
                ? reconstructedLink.link.absoluteString
                : reconstructedLink.link
                    .appendingPathComponent(animeResourceTags.episode)
                    .absoluteString
        }
    }
    
    struct ServerInformation {
        var bowl: SwiftSoup.Document
        var serverOptions: [Anime.ServerIdentifier: String]
        var episodeServerMap: Anime.EpisodesCollection
    }
    
    func _parseAnime(from page: String, with link: AnimeLink) -> NineAnimatorPromise<Anime> {
        renewSession(referer: link.link.absoluteString).then {
            try self._parseAnimePage(page, link: link)
        } .thenPromise {
            initialPageInformation -> NineAnimatorPromise<(AnimeInitialPageInformation, NSDictionary)> in
            NineAnimatorPromise {
                var requestParameters: [URLQueryItem] = [
                    "id": initialPageInformation.animeResourceTags.id
                ]
                
                if !initialPageInformation.animeResourceTags.episode.isEmpty {
                    requestParameters.append(.init(
                        name: "episode",
                        value: initialPageInformation.animeResourceTags.episode
                    ))
                }
                
                return self.signedRequest(
                    ajax: "/ajax/film/servers",
                    parameters: requestParameters,
                    with: [ "Referer": initialPageInformation.referer ],
                    completion: $0
                )
            } .then { (initialPageInformation, $0) }
        } .then {
            initialPage, serversPageResponseDict in
            // Obtain servers and episodes information
            let serversPage = try self._parseServersPage(
                serversPageResponseDict,
                link: initialPage.reconstructedLink
            )
            
            // Construct Anime object
            return Anime(
                initialPage.reconstructedLink,
                alias: initialPage.alias,
                additionalAttributes: initialPage.attributes,
                description: initialPage.description,
                on: serversPage.serverOptions,
                episodes: serversPage.episodeServerMap
            )
        }
    }
    
    func _parseServersPage(_ serversResponse: NSDictionary, link: AnimeLink) throws -> ServerInformation {
        let responseRawHtmlEntry = try serversResponse.value(
            at: "html",
            type: String.self
        )
        var results = ServerInformation(
            bowl: try SwiftSoup.parse(responseRawHtmlEntry),
            serverOptions: [:],
            episodeServerMap: [:]
        )
        
        // Map server to name
        results.serverOptions = try results.bowl
            .select("span.tab")
            .reduce(into: results.serverOptions) {
                $0[try $1.attr("data-name")] = $1.ownText()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        
        // Map server to episodes
        results.episodeServerMap = try results.bowl
            .select("div.server")
            .reduce(into: results.episodeServerMap) {
                episodeServerMap, serverElement in
                let serverIdentifier = try serverElement.attr("data-id")
                episodeServerMap[serverIdentifier] = try serverElement
                    .select(".episodes a")
                    .map {
                        let dataIdentifier = try $0.attr("data-id")
                        let pathIdentifier = try $0.attr("href")
                        return EpisodeLink(
                            identifier: "\(dataIdentifier)|\(pathIdentifier)",
                            name: try $0.text(),
                            server: serverIdentifier,
                            parent: link
                        )
                    }
            }
        
        return results
    }
    
    func _parseAnimePage(_ pageContent: String, link: AnimeLink) throws -> AnimeInitialPageInformation {
        var result = AnimeInitialPageInformation(
            bowl: try SwiftSoup.parse(pageContent),
            reconstructedLink: link,
            animeResourceTags: ("", ""),
            attributes: [:],
            alias: (NASourceNineAnimeOld.animeAliasRegex
                .firstMatch(in: pageContent)?
                .firstMatchingGroup) ?? "",
            description: ""
        )
        
        let serverContainerElement = try result.bowl.select("div#servers-container")
                                
        result.animeResourceTags = (
            id: try serverContainerElement.attr("data-id"),
            episode: try serverContainerElement.attr("data-epid")
        )
        
        // Basic information
        result.alias = (try? result.bowl.select(".info .alias").text()) ?? ""
        result.description = (try? result.bowl.select("div.desc").text()) ?? "No description"
        
        // Reconstructing AnimeLink from the page content
        let animePosterURL = processRelativeUrl(
            try result.bowl.select("div.thumb>img").attr("src"),
            base: link.link
        ) ?? link.image
        let animeTitle = try result.bowl.select(".info .title").text()
        result.reconstructedLink = AnimeLink(
            title: animeTitle,
            link: link.link,
            image: animePosterURL,
            source: link.source
        )
        
        // Parse attributes
        let animeAttributesRaw: [String: String] = {
            do {
                let zippedSequence = zip(
                    try result.bowl
                        .select("div.info>div.row dt")
                        .array()
                        .map { try $0.text() },
                    try result.bowl
                        .select("div.info>div.row dd")
                        .array()
                        .map { try $0.text() }
                )
                return Dictionary(zippedSequence) { $1 }
            } catch { return [:] }
        }()
        
        for (key, value) in animeAttributesRaw {
            switch key.lowercased() {
            case "rating:":
                let labels = value.split(separator: "/")
                guard let ratingString = labels.first?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    let rating = Float(String(ratingString)) else { continue }
                
                result.attributes[.rating] = rating
                result.attributes[.ratingScale] = Float(10.0)
            case "date aired:":
                result.attributes[.airDate] = value
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            default: continue
            }
        }
        
        return result
    }
}

extension NASourceNineAnimeOld {
    /// Process protocol-relative URLs
    func processRelativeUrl(_ input: String, base: URL? = nil) -> URL? {
        URL(
            string: input.hasPrefix("//") ? "https:" + input : input,
            relativeTo: base
        )
    }
}
