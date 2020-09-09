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

class NineAnimeSearch: ContentProvider {
    private(set) var title: String
    private(set) var totalPages: Int?
    weak var delegate: ContentProviderDelegate?
    
    var moreAvailable: Bool { totalPages == nil || _results.count < totalPages! }
    
    var availablePages: Int { _results.count }
    
    private var _results: [[AnimeLink]]
    private var _lastRequest: NineAnimatorAsyncTask?
    private let _parent: NASourceNineAnime
    
    init(_ parent: NASourceNineAnime, query: String) {
        self.title = query
        self._results = []
        self._parent = parent
    }
    
    deinit { _lastRequest?.cancel() }
    
    func links(on page: Int) -> [AnyLink] { _results[page].map { .anime($0) } }
    
    func more() {
        guard moreAvailable && _lastRequest == nil else { return }
        Log.debug("Requesting page %@ for query %@", _results.count + 1, title)
        let loadingIndex = _results.count
        _lastRequest = _parent.signedRequest(
            browse: "/search",
            parameters: [
                "keyword": title,
                "page": _results.count + 1
            ]
        ) { [weak self] response, error in
            guard let self = self else { return }
            defer { self._lastRequest = nil }
            
            if self._results.count > loadingIndex { return }
            
            guard let response = response else {
                self.delegate?.onError(error ?? NineAnimatorError.searchError("Response cannot be parsed."), from: self)
                return Log.error(error)
            }
            
            do {
                let bowl = try SwiftSoup.parse(response)
                
                if let totalPagesString = try? bowl.select("span.total").text(),
                    let totalPages = Int(totalPagesString) {
                    self.totalPages = totalPages
                } else {
                    self.totalPages = 1
                }
                
                let films = try bowl.select("div.film-list>div.item")
                let animes: [AnimeLink] = try films.compactMap { film in
                    let nameElement = try film.select("a.name")
                    let name = try nameElement.text()
                    let linkString = try nameElement.attr("href")
                    let coverImageElement = try film.select("img")
                    
                    let coverImage = try ( // Either in src or data-src
                        self._parent.processRelativeUrl(try coverImageElement.attr("src"))
                        ?? self._parent.processRelativeUrl(try coverImageElement.attr("data-src"))
                        ?? NineAnimator.placeholderArtworkUrl
                    )
                    
                    guard let link = URL(string: linkString) else {
                        Log.error("An invalid link (%@) was extracted from the search result page", linkString)
                        return nil
                    }
                    
                    return AnimeLink(title: name, link: link, image: coverImage, source: self._parent)
                }
                
                if animes.isEmpty {
                    Log.debug("No results found for '@%'", self.title)
                    self.totalPages = 0
                    self.delegate?.onError(NineAnimatorError.searchError("No results found for \"\(self.title)\""), from: self)
                } else {
                    let newSection = self._results.count
                    self._results.append(animes)
                    self.delegate?.pageIncoming(newSection, from: self)
                }
            } catch {
                self.delegate?.onError(error, from: self)
                Log.error("Error when loading more results: %@", error)
            }
        }
    }
}

extension NASourceNineAnime {
    func search(keyword: String) -> ContentProvider {
        NineAnimeSearch(self, query: keyword)
    }
}
