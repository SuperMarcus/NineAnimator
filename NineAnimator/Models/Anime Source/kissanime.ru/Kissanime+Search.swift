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

extension NASourceKissanime {
    class SearchAgent: ContentProvider {
        var totalPages: Int? { 1 }
        var availablePages: Int { _results == nil ? 0 : 1 }
        var moreAvailable: Bool { _results == nil }
        
        private let parent: NASourceKissanime
        private var requestTask: NineAnimatorAsyncTask?
        private var _results: [AnimeLink]?
        var title: String
        
        weak var delegate: ContentProviderDelegate?
        
        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        
        func more() {
            guard requestTask == nil && moreAvailable else { return }
            requestTask = parent.request(
                browsePath: "/Search/Anime",
                query: [ "keyword": title ]
            ) .then {
                [weak self] responseContent -> [AnimeLink] in
                guard let self = self else { throw NineAnimatorError.unknownError }
                
                // Parse the response content
                let bowl = try SwiftSoup.parse(responseContent)
                let entries = try bowl.select("table.listing td")
                let resultingLinks = entries.compactMap {
                    entry -> AnimeLink? in
                    do {
                        let linkContainer = try entry.select("a").first().tryUnwrap()
                        let animeLinkPath = try linkContainer.attr("href")
                        let animeUrl = try URL(
                            string: animeLinkPath,
                            relativeTo: self.parent.endpointURL
                        ).tryUnwrap()
                        let animeTitle = linkContainer
                            .ownText()
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let containerTitleContent = try entry.attr("title")
                        let tooltipContainer = try SwiftSoup.parse(containerTitleContent)
                        let animeArtworkPath = try tooltipContainer.select("img").attr("src")
                        let animeArtworkUrl = self.parent.processArtworkUrl(try URL(
                            string: animeArtworkPath,
                            relativeTo: self.parent.endpointURL
                        ).tryUnwrap())
                        
                        // Construct the AnimeLink
                        return AnimeLink(
                            title: animeTitle,
                            link: animeUrl,
                            image: animeArtworkUrl,
                            source: self.parent
                        )
                    } catch { return nil }
                }
                
                guard !resultingLinks.isEmpty else {
                    throw NineAnimatorError.searchError("No results found")
                }
                
                return resultingLinks
            } .error {
                [weak self] error in
                guard let self = self else { return }
                self.delegate?.onError(error, from: self)
                self.requestTask = nil
            } .finally {
                [weak self] results in
                guard let self = self else { return }
                self._results = results
                self.delegate?.pageIncoming(0, from: self)
                self.requestTask = nil
            }
        }
        
        init(query: String, parent: NASourceKissanime) {
            self.title = query
            self.parent = parent
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        SearchAgent(query: keyword, parent: self)
    }
}
