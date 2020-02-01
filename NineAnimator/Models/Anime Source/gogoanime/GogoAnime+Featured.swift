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

extension NASourceGogoAnime {
    fileprivate static let animePosterImageRegex =
        try! NSRegularExpression(pattern: "background:\\s*url\\('([^']+)", options: .caseInsensitive)
    static let animeLinkFromEpisodePathRegex =
        try! NSRegularExpression(pattern: "\\/(.+)-episode-\\d+$", options: .caseInsensitive)
    
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        NineAnimatorPromise<[AnimeLink]>.queue(listOfPromises: [
            popularAnimeUpdates, latestAnimeUpdates
        ]) .then { results in BasicFeaturedContainer(featured: results[0], latest: results[1]) }
    }
    
    fileprivate var latestAnimeUpdates: NineAnimatorPromise<[AnimeLink]> {
        // Browse home
        return request(browsePath: "/")
            .then {
                content -> [AnimeLink] in
                Log.info("Loading GogoAnime ongoing releases page")
                let bowl = try SwiftSoup.parse(content)
                return try bowl
                    .select(".last_episodes>ul>li")
                    .compactMap {
                        item -> AnimeLink? in
                        let linkContainer = try item.select(".img>a")
                        
                        // The link is going to be something like '/xxx-xxxx-episode-##'
                        let episodePath = try linkContainer.attr("href")
                        
                        // Match the anime identifier with regex
                        let animeIdentifierMatches = NASourceGogoAnime
                            .animeLinkFromEpisodePathRegex
                            .matches(in: episodePath, options: [], range: episodePath.matchingRange)
                        guard let animeIdentifierMatch = animeIdentifierMatches.first else { return nil }
                        let animeIdentifier = episodePath[animeIdentifierMatch.range(at: 1)]
                        
                        // Reassemble the anime URL to something like '/category/xxx-xxxx'
                        guard let animeUrl = URL(string: "\(self.endpoint)/category/\(animeIdentifier)") else {
                            return nil
                        }
                        
                        // Read the link to the artwork
                        guard let artworkUrl = URL(string: try linkContainer.select("img").attr("src")) else {
                            return nil
                        }
                        
                        let animeTitle = try item.select("p.name").text()
                        
                        return AnimeLink(
                            title: animeTitle,
                            link: animeUrl,
                            image: artworkUrl,
                            source: self
                        )
                    }
            }
    }
    
    fileprivate var popularAnimeUpdates: NineAnimatorPromise<[AnimeLink]> {
        request(ajaxUrlString: ajaxEndpoint.appendingPathComponent("/ajax/page-recent-release-ongoing.html"))
            .then {
                content -> [AnimeLink] in
                Log.info("Loading GogoAnime popular releases page")
                let bowl = try SwiftSoup.parse(content)
                return try bowl
                    .select(".added_series_body>ul>li")
                    .compactMap {
                        item -> AnimeLink? in
                        guard let firstLinkElement = try item.select("a").first(),
                            let animeURL = URL(string: "\(self.endpoint)\(try firstLinkElement.attr("href"))") else {
                                return nil
                        }
                        
                        let backgroundImageContainerStyle = try item
                            .select("div.thumbnail-popular")
                            .attr("style")
                        let backgroundImageURLMatches = NASourceGogoAnime.animePosterImageRegex
                            .matches(in: backgroundImageContainerStyle, options: [], range: backgroundImageContainerStyle.matchingRange)
                        
                        guard let firstMatch = backgroundImageURLMatches.first else { return nil }
                        
                        guard let imageUrl = URL(string: backgroundImageContainerStyle[firstMatch.range(at: 1)]) else {
                            return nil
                        }
                        
                        return AnimeLink(
                            title: try firstLinkElement.attr("title"),
                            link: animeURL,
                            image: imageUrl,
                            source: self
                        )
                    }
            }
    }
    
    /// Implementation for the new featured page
    fileprivate func newFeatured() -> NineAnimatorPromise<FeaturedContainer> {
        request(browsePath: "/").then { content -> FeaturedContainer in
            Log.info("[NASourceGogoAnime] Loading FeaturedContainer")
            
            // Parse html contents
            let bowl = try SwiftSoup.parse(content)
            
            // Links for updated anime
            let updatedAnimeContainer = try bowl.select(".new-latest")
            let latestAnime = try updatedAnimeContainer.select(".nl-item").map {
                element -> AnimeLink in
                let urlString = try element.select("a.nli-image").attr("href")
                let url = try URL(string: urlString).tryUnwrap(.urlError)
                let artwork = try element.select("img").attr("src")
                let artworkUrl = try URL(string: artwork).tryUnwrap(.urlError)
                let title = try element.select("nli-serie").text()
                return AnimeLink(title: title, link: url, image: artworkUrl, source: self)
            }
            
            // Links for popular anime
            let popularAnimeContainer = try bowl.select(".ci-contents .bl-box").map {
                element -> AnimeLink in
                let linkElement = try element.select("a.blb-title")
                let title = try linkElement.text()
                let urlString = try linkElement.attr("href")
                let url = try URL(string: urlString).tryUnwrap(.urlError)
                let artwork = try element.select(".blb-image>img").attr("src")
                let artworkUrl = try URL(string: artwork).tryUnwrap(.urlError)
                return AnimeLink(title: title, link: url, image: artworkUrl, source: self)
            }
            
            // Construct a basic featured anime container
            return BasicFeaturedContainer(featured: popularAnimeContainer, latest: latestAnime)
        }
    }
}
