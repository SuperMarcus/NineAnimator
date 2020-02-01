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

// swiftlint:disable closure_end_indentation
extension NASourceGogoAnime {
    class GogoContentProvider: ContentProvider {
        var title: String
        
        var totalPages: Int?
        
        var availablePages: Int { _results.count }
        
        var moreAvailable: Bool {
            guard let pages = totalPages else { return true }
            return pages > availablePages
        }
        
        weak var delegate: ContentProviderDelegate?
        
        private unowned let _parent: NASourceGogoAnime
        
        private var _results = [[AnimeLink]]()
        
        private var _lastRequest: NineAnimatorAsyncTask?
        
        init(query: String, parent: NASourceGogoAnime) {
            self._parent = parent
            self.title = query
        }
        
        func links(on page: Int) -> [AnyLink] {
            _results[page].map { .anime($0) }
        }
        
        func more() {
            if _lastRequest == nil && moreAvailable {
                guard var urlBuilder = URLComponents(
                    url: _parent.endpointURL.appendingPathComponent("/search.html"),
                    resolvingAgainstBaseURL: true
                ) else {
                    Log.error("Cannot resolve search URL")
                    return
                }
                let requestingPage = availablePages
                Log.info("Requesting page %d", requestingPage)
                
                // Set GET parameters
                urlBuilder.queryItems = [
                    .init(name: "keyword", value: title),
                    .init(name: "page", value: "\(requestingPage + 1)")
                ]
                guard let url = urlBuilder.url else {
                    Log.error("Cannot generate search URL")
                    return
                }
                _lastRequest = _parent
                    .request(browseUrl: url)
                    .then {
                        [weak self] content -> [AnimeLink]? in
                        guard let self = self else { return nil }
                        
                        let bowl = try SwiftSoup.parse(content)
                        
                        // Save total pages
                        self.totalPages = try bowl
                            .select("ul.pagination-list a")
                            .compactMap { Int(try $0.attr("data-page")) }
                            .max()
                        
                        let resultingLinks = try bowl.select("ul.items>li").compactMap {
                            item -> AnimeLink? in
                            // Fetch image poster url
                            guard let artworkUrl = URL(string: try item.select(".img img").attr("src")) else {
                                return nil
                            }
                            
                            // Fetch title and path
                            let animeTitle = try item.select("p.name").text()
                            let animePath = try item.select("p.name>a").attr("href")
                            
                            // Construct anime url
                            let animeUrl = self._parent.endpointURL.appendingPathComponent(animePath)
                            
                            // Construct anime link struct
                            return AnimeLink(
                                title: animeTitle,
                                link: animeUrl,
                                image: artworkUrl,
                                source: self._parent
                            )
                        }
                        
                        // If no results or all of the results are on a single page
                        if self.totalPages == nil {
                            if resultingLinks.isEmpty {
                                throw NineAnimatorError.searchError("No results found")
                            } else { self.totalPages = 1 }
                        }
                        
                        return resultingLinks
                    } .error {
                        [weak self] in
                        guard let self = self else { return }
                        defer { self._lastRequest = nil }
                        self.delegate?.onError($0, from: self)
                    } .finally {
                        [weak self] in
                        guard let self = self else { return }
                        defer { self._lastRequest = nil }
                        
                        if $0.isEmpty {
                            Log.info("No results found for '%@'", self.title)
                            self.delegate?.onError(
                                NineAnimatorError.searchError("No results found for \"\(self.title)\""),
                                from: self
                            )
                        } else {
                            Log.info("%@ results on page %@", $0.count, requestingPage)
                            self._results.append($0)
                            self.delegate?.pageIncoming(requestingPage, from: self)
                        }
                    }
            }
        }
    }
}
