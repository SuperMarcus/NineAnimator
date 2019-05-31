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

extension NASourceWonderfulSubs {
    class SearchAgent: ContentProvider {
        private let query: String
        private unowned let parent: NASourceWonderfulSubs
        private var _queryTask: NineAnimatorAsyncTask?
        
        weak var delegate: ContentProviderDelegate?
        
        // Accessing results
        var totalPages: Int? = 1
        var availablePages: Int = 1
        var results: [AnimeLink]?
        var moreAvailable: Bool { return results == nil }
        var title: String { return query }
        
        func links(on page: Int) -> [AnyLink] {
            return results?.map { .anime($0) } ?? []
        }
        
        func more() {
            guard _queryTask == nil, moreAvailable else { return }
            _queryTask = parent
                .request(
                    ajaxPathDictionary: "/api/media/search",
                    query: [ "q": query ]
                )
                .then {
                    [unowned parent] response -> [AnimeLink] in
                    let seriesObjects = try response.value(at: "json.series", type: [NSDictionary].self)
                    let objects = try seriesObjects.map { try parent.constructAnimeLink(from: $0) }
                    guard !objects.isEmpty else {
                        throw NineAnimatorError.searchError("No results found")
                    }
                    return objects
                } .error {
                    [weak self] error in
                    guard let self = self else { return }
                    self.results = []
                    self.delegate?.onError(error, from: self)
                    self._queryTask = nil
                } .finally {
                    [weak self] results in
                    guard let self = self else { return }
                    self.results = results
                    self.delegate?.pageIncoming(0, from: self)
                    self._queryTask = nil
                }
        }
        
        init(_ query: String, parent: NASourceWonderfulSubs) {
            self.query = query
            self.parent = parent
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        return SearchAgent(keyword, parent: self)
    }
}
