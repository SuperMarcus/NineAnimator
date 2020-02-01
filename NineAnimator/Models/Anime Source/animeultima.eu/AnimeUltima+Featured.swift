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

extension NASourceAnimeUltima {
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        request(browsePath: "/")
            .then {
                result -> FeaturedContainer? in
                // Parse and select the sections
                let bowl = try SwiftSoup.parse(result)
                let sections = try bowl.select("section.section")
                
                // Make sure we at least have two sections in the response
                guard sections.size() >= 2 else {
                    throw NineAnimatorError.responseError("NineAnimator cannot found any anime on AnimeUltima.")
                }
                
                // Obtain the two sections for presentation
                let lastUpdatedSectionContainer = sections.get(0)
                let featuredAnimeSectionContainer = sections.get(1)
                
                // Do the parsing
                let lastUpdatedLinks = try self.retrieveLastUpdatedLinks(from: lastUpdatedSectionContainer)
                let featuredLinks = try self.retrieveFeaturedLinks(from: featuredAnimeSectionContainer)
                
                // Construct a static featured container
                return BasicFeaturedContainer(featured: featuredLinks, latest: lastUpdatedLinks)
            }
    }
    
    fileprivate func retrieveFeaturedLinks(from featuredAnimeSectionContainer: SwiftSoup.Element) throws -> [AnimeLink] {
        try featuredAnimeSectionContainer
            .select("div.anime-box")
            .map {
                animeContainer -> AnimeLink in
                // Obtain the url string from the href attribute
                let animeUrlString = try animeContainer.select("a").attr("href")
                guard let animeUrl = URL(string: animeUrlString) else {
                    throw NineAnimatorError.urlError
                }
                
                // Compile a regex to match the anime artwork url from the style
                // attribute of the figure
                let artworkMatchingRegex = try NSRegularExpression(
                    pattern: "background:\\s+url\\('([^']+)",
                    options: [ .caseInsensitive ]
                )
                let artworkUrlString = try some(
                    artworkMatchingRegex.firstMatch(
                        in: try animeContainer.select("figure").attr("style")
                    )?.firstMatchingGroup,
                    or: .responseError("Unable to find the artworks related to the anime")
                )
                guard let artworkUrl = URL(string: artworkUrlString) else {
                    throw NineAnimatorError.urlError
                }
                
                // At last, obtain the title of the anime
                let animeTitle = try animeContainer
                    .select("span.anime-title")
                    .text()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                return AnimeLink(title: animeTitle, link: animeUrl, image: artworkUrl, source: self)
            }
    }
    
    fileprivate func retrieveLastUpdatedLinks(from lastUpdatedSectionContainer: SwiftSoup.Element) throws -> [AnimeLink] {
        // Select the last updated cards
        return try lastUpdatedSectionContainer
            .select("div.episode-scroller>.card")
            .map {
                cardContainer -> AnimeLink in
                // Use the first link's target address
                let episodeUrlString = try cardContainer.select("a").attr("href")
                guard let episodeUrl = URL(string: episodeUrlString) else {
                    throw NineAnimatorError.urlError
                }
                
                // Retrieve the anime url by deleting the last path component of AnimeUltima's url
                let animeUrl = episodeUrl.deletingLastPathComponent()
                
                // Retrieve the anime artwork
                let artworkContainer = try cardContainer.select("img")
                let artworkUrlString = try ((try? {
                    // Try with the largest image in the srcset attribute
                    try some(
                        try artworkContainer.attr("srcset").split(separator: " ").first?.description,
                        or: NineAnimatorError.unknownError
                    )
                    }()) ?? (try artworkContainer.attr("src"))) // Fallback to src attribute
                guard let artworkUrl = URL(string: artworkUrlString) else {
                    throw NineAnimatorError.urlError
                }
                
                // At last, retrieve the anime title
                let animeTitle = try cardContainer
                    .select("span.episode-title")
                    .text()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                return AnimeLink(title: animeTitle, link: animeUrl, image: artworkUrl, source: self)
        }
    }
}
