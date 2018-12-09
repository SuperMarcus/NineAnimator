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

protocol SearchPageDelegate: AnyObject {
    //Index of the page (starting from zero)
    func pageIncoming(_: Int, in: SearchPage)
    
    func noResult(in: SearchPage)
}

class SearchPage {
    private(set) var query: String
    private(set) var totalPages: Int?
    weak var delegate: SearchPageDelegate?
    
    var moreAvailable: Bool {
        return totalPages == nil || _results.count < totalPages!
    }
    
    var availablePages: Int { return _results.count }
    
    private var _results: [[AnimeLink]]
    private var _animator: NineAnimator
    private var _lastRequest: NineAnimatorAsyncTask? = nil
    
    init(_ animator: NineAnimator, query: String) {
        self.query = query
        self._animator = animator
        self._results = []
        //Request the first page
        more()
    }
    
    deinit {
        _lastRequest?.cancel()
    }
    
    func animes(on page: Int) -> [AnimeLink] { return _results[page] }
    
    func more() {
        if moreAvailable && _lastRequest == nil {
            debugPrint("Info: Requesting page \(_results.count + 1) for query \(query)")
            let loadingIndex = _results.count
            _lastRequest = _animator.request(.search(keyword: query, page: loadingIndex + 1)) {
                [weak self] response, error in
                guard let self = self else { return }
                defer { self._lastRequest = nil }
                
                if self._results.count > loadingIndex { return }
                
                guard let response = response else {
                    debugPrint("Error: \(error!)")
                    return
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
                        let coverImageString = try film.select("img").attr("src")
                        
                        guard let link = URL(string: linkString),
                            let coverImage = URL(string: coverImageString)
                            else {
                                debugPrint("Warn: an invalid link was extracted from the search result page")
                                return nil
                        }
                        
                        return AnimeLink(title: name, link: link, image: coverImage)
                    }
                    
                    if animes.count > 0 {
                        let newSection = self._results.count
                        self._results.append(animes)
                        self.delegate?.pageIncoming(newSection, in: self)
                    } else {
                        debugPrint("Info: No matches")
                        self.totalPages = 0
                        self.delegate?.noResult(in: self)
                    }
                } catch {
                    debugPrint("Error when loading more results: \(error)")
                }
            }
        }
    }
}

extension NineAnimator {
    func search(_ keyword: String) -> SearchPage {
        return SearchPage(self, query: keyword)
    }
}
