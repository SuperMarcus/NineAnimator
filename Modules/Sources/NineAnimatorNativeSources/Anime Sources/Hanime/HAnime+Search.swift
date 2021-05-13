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

import Alamofire
import Foundation
import NineAnimatorCommon

extension NASourceHAnime {
    struct SearchAPIResponse: Codable {
        let page: Int
        let nbPages: Int
        let nbHits: Int
        let hits: String
    }

    struct SearchResults: Codable {
        let name: String
        let slug: String
        let coverUrl: String
    }
    
    typealias SearchHits = [SearchResults]
    
    class SearchAgent: ContentProvider {
        var title: String

        var totalPages: Int?
        var availablePages: Int { _results.count }
        var moreAvailable: Bool { totalPages == nil || _results.count < totalPages! }

        weak var delegate: ContentProviderDelegate?
        private var parent: NASourceHAnime
        private var performingTask: NineAnimatorAsyncTask?
        private var _results: [[AnimeLink]]

        func links(on page: Int) -> [AnyLink] { _results[page].map { .anime($0) } }
        
        deinit { performingTask?.cancel() }
        
        func more() {
            guard moreAvailable && performingTask == nil else { return }
            Log.debug("Requesting page %@ for query %@", _results.count, title)
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            performingTask = parent.requestManager.request(
                url: "https://search.htv-services.com",
                handling: .default,
                method: .post,
                parameters: [
                    "blacklist": [String](),
                    "brands": [String](),
                    "order_by": "created_at_unix",
                    "ordering": "desc",
                    "page": self._results.count,
                    "search_text": title,
                    "tags": [String](),
                    "tags_mode": "AND"
                ],
                encoding: JSONEncoding.default
            ).responseDecodable(
                type: SearchAPIResponse.self,
                decoder: decoder
            ) .then {
                responseObject -> ([AnimeLink], Int) in
                let hitsData = try responseObject.hits.data(using: .utf8)
                    .tryUnwrap(.providerError("Couldn't encode JSON data"))
                
                let hits = try decoder.decode(SearchHits.self, from: hitsData)
                let hanime = try hits.compactMap {
                    hit -> AnimeLink in
                    let animeTitle = hit.name
                    
                    let artworkString = try self.parent.jetpack(url: hit.coverUrl, quality: 100, cdn: "cps")
                    let animeArtworkUrl = try URL(string: artworkString)
                        .tryUnwrap(.urlError)
                    
                    let animeUrl = try URL(string: "/videos/hentai/", relativeTo: self.parent.endpointURL)
                        .tryUnwrap(.urlError)
                    let animeLink = try URL(string: hit.slug, relativeTo: animeUrl)
                            .tryUnwrap(.urlError)
                    
                    return AnimeLink(
                        title: animeTitle,
                        link: animeLink,
                        image: animeArtworkUrl,
                        source: self.parent
                    )
                }
                
                return (hanime, responseObject.nbPages)
            } .then {
                results, pages -> ([AnimeLink], Int) in
                if results.isEmpty {
                    throw NineAnimatorError.searchError("No results found")
                } else { return (results, pages) }
            } .error {
                [weak self] in
                guard let self = self else { return }
                
                self.totalPages = 0
                
                // Reset performing task if the error is not 404
                if !($0 is NineAnimatorError.SearchError) {
                    self.performingTask = nil
                }

                self.delegate?.onError($0, from: self)
            } .finally {
                [weak self] in
                guard let self = self else { return }
                self.totalPages = $0.1
                self.performingTask = nil
                
                let newSection = self._results.count
                self._results.append($0.0)
                self.delegate?.pageIncoming(newSection, from: self)
            }
        }

        init(_ query: String, withParent parent: NASourceHAnime) {
            self.parent = parent
            self.title = query
            self._results = []
        }
    }

    func search(keyword: String) -> ContentProvider {
        SearchAgent(keyword, withParent: self)
    }
}
