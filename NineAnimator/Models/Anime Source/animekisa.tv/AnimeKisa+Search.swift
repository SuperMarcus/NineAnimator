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

extension NASourceAnimeKisa {
    class SearchAgent: ContentProvider {
        var title: String
        
        var totalPages: Int? { 1 }
        var availablePages: Int { _results == nil ? 0 : 1 }
        var moreAvailable: Bool { _results == nil }
        
        weak var delegate: ContentProviderDelegate?
        private var parent: NASourceAnimeKisa
        private var performingTask: NineAnimatorAsyncTask?
        private var _results: [AnimeLink]?
        
        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        
        func more() {
            guard performingTask == nil && moreAvailable else { return }
            performingTask = parent.request(
                browsePath: "/search",
                query: [ "q": title ]
            ) .then {
                [weak self] responseContent -> [AnimeLink]? in
                guard let self = self else { return nil }
                let bowl = try SwiftSoup.parse(responseContent)
                let relativeUrlBase = self.parent.endpointURL.appendingPathComponent("search")
                let results = try bowl.select("a.an").compactMap {
                    resultContainer -> AnimeLink? in
                    do {
                        let artworkPath = try resultContainer
                            .select("div.similarpic>img.coveri")
                            .attr("src")
                        let artworkUrl = try URL(
                            string: artworkPath,
                            relativeTo: relativeUrlBase
                        ).tryUnwrap()
                        let animeUrl = try URL(
                            string: try resultContainer.attr("href"),
                            relativeTo: relativeUrlBase
                        ).tryUnwrap()
                        let animeTitle = try resultContainer
                            .select("div.similard")
                            .text()
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return AnimeLink(
                            title: animeTitle,
                            link: animeUrl,
                            image: artworkUrl,
                            source: self.parent
                        )
                    } catch { return nil }
                }
                guard !results.isEmpty else {
                    throw NineAnimatorError.searchError("No results found")
                }
                return results
            } .error {
                [weak self] error in
                guard let self = self else { return }
                self.delegate?.onError(error, from: self)
                self.performingTask = nil
            } .finally {
                [weak self] results in
                guard let self = self else { return }
                self._results = results
                self.delegate?.pageIncoming(0, from: self)
                self.performingTask = nil
            }
        }
        
        init(_ query: String, withParent parent: NASourceAnimeKisa) {
            self.parent = parent
            self.title = query
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        SearchAgent(keyword, withParent: self)
    }
}
