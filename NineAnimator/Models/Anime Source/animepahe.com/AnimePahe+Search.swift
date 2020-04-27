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

extension NASourceAnimePahe {
    fileprivate struct SearchResponse: Codable {
        var total: Int
        var data: [SearchAnimeItem]
    }
    
    fileprivate struct SearchAnimeItem: Codable {
        var slug: String
        var title: String
        var poster: String
    }
    
    class SearchAgent: ContentProvider {
        weak var delegate: ContentProviderDelegate?
        
        private var searchResults: [AnimeLink]?
        private var performingTask: NineAnimatorAsyncTask?
        private(set) var title: String
        private(set) var totalPages: Int?
        private let parent: NASourceAnimePahe
        
        var availablePages: Int { searchResults == nil ? 0 : 1 }
        var moreAvailable: Bool { searchResults == nil }
        
        func links(on page: Int) -> [AnyLink] {
            searchResults?.map { .anime($0) } ?? []
        }
        
        func more() {
            guard performingTask == nil else { return }
            performingTask = parent.request(
                ajaxPathDictionary: "/api",
                query: [ "m": "search", "l": 64, "q": title ]
            ) .then {
                // Decode the search response
                try DictionaryDecoder().decode(SearchResponse.self, from: $0)
            } .then {
                [weak self] decodedSearchResponse -> [AnimeLink]? in
                guard let self = self else { return nil }
                return try decodedSearchResponse.data.map {
                    item in AnimeLink(
                        title: item.title,
                        link: self.parent.animeBaseUrl.appendingPathComponent(item.slug),
                        image: try URL(string: item.poster).tryUnwrap(.urlError),
                        source: self.parent
                    )
                }
            } .error {
                [weak self] error in
                guard let self = self else { return }
                self.delegate?.onError(error, from: self)
                self.performingTask = nil
            } .finally {
                [weak self] searchResults in
                guard let self = self else { return }
                self.searchResults = searchResults
                self.delegate?.pageIncoming(0, from: self)
                self.performingTask = nil
            }
        }
        
        init(_ parent: NASourceAnimePahe, keywords: String) {
            self.parent = parent
            self.title = keywords
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        SearchAgent(self, keywords: keyword)
    }
}
