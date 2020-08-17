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

extension NASourceAnimeHub {
    class SearchAgent: ContentProvider {
        var title: String

        var totalPages: Int? { 1 }
        var availablePages: Int { _results == nil ? 0 : 1 }
        var moreAvailable: Bool { _results == nil }

        weak var delegate: ContentProviderDelegate?
        private var parent: NASourceAnimeHub
        private var performingTask: NineAnimatorAsyncTask?
        private var _results: [AnimeLink]?

        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        
        func more() {
            if performingTask == nil {
                // Animehub includes the search title in the URL path, rather than as a URL query param.
                let encodedTitle = self.title.replacingOccurrences(of: " ", with: "+")
                
                performingTask = parent.requestManager.request(
                    "/search/\(encodedTitle)",
                    handling: .browsing
                ).responseString.then {
                    [parent] responseContent -> [AnimeLink]? in
                    try SwiftSoup.parse(responseContent)
                        .select("ul.ulclear.grid-item > li").compactMap {
                            animeContainer -> AnimeLink? in
                            let animeArtworkURL = try URL(
                                string: animeContainer.select("a.thumb > img").attr("src")
                            ) ?? NineAnimator.placeholderArtworkUrl
                            
                            let animeLink = try URL(
                                string: animeContainer.select("a.thumb").attr("href")
                            ).tryUnwrap(NineAnimatorError.urlError)
                            
                            let animeTitle = try animeContainer.select("a.thumb").attr("title")
                            
                            return AnimeLink(
                                title: animeTitle,
                                link: animeLink,
                                image: animeArtworkURL,
                                source: parent
                            )
                    }
                } .then {
                    results -> [AnimeLink] in
                    if results.isEmpty {
                        throw NineAnimatorError.searchError("No results found")
                    } else { return results }
                } .error {
                    [weak self] in
                    guard let self = self else { return }

                    // Reset performing task if the error is not 404
                    if !($0 is NineAnimatorError.SearchError) {
                        self.performingTask = nil
                    }

                    self.delegate?.onError($0, from: self)
                } .finally {
                    [weak self] in
                    guard let self = self else { return }
                    self._results = $0
                    self.delegate?.pageIncoming(0, from: self)
                }
            }
        }
        init(_ query: String, withParent parent: NASourceAnimeHub) {
            self.parent = parent
            self.title = query
        }
    }
    func search(keyword: String) -> ContentProvider {
        SearchAgent(keyword, withParent: self)
    }
}
