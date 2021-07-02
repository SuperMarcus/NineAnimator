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

extension NASourceArrayanime {
    fileprivate struct SearchResponse: Decodable {
        let results: [SearchEntry]
    }

    fileprivate struct SearchEntry: Decodable {
        let id: String
        let title: String
        let image: String
    }

    class SearchAgent: ContentProvider {
        var title: String

        var totalPages: Int?
        var availablePages: Int { _results.count }
        var moreAvailable: Bool { totalPages == nil || _results.count <= totalPages! }
        
        weak var delegate: ContentProviderDelegate?
        private var parent: NASourceArrayanime
        private var performingTask: NineAnimatorAsyncTask?
        private var _results = [[AnimeLink]]()
        
        func links(on page: Int) -> [AnyLink] {
            _results[page].map { .anime($0) }
        }
        
        func more() {
            guard moreAvailable && performingTask == nil else { return }
            
            // Arrayanime includes the search title in the URL path, hence need to encode
            let encodedTitle = self.title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            let newPage = availablePages
            
            performingTask = parent.requestManager.request(
                url: parent.searchEndpoint.appendingPathComponent("/search/\(encodedTitle ?? "")/\(newPage + 1)"),
                handling: .ajax
            ) .responseDecodable(type: SearchResponse.self).then {
                searchResponse -> [AnimeLink] in
                let searchResults = try searchResponse.results.map {
                    searchEntry -> AnimeLink in
                    
                    let encodedImage = try searchEntry.image
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) // Thanks uttiya
                    .tryUnwrap(.urlError)
                    
                    let animeURL = try URL(string: self.parent.endpoint + "/ani/\(searchEntry.id)").tryUnwrap(.urlError)
                    let animeImage = try URL(
                        protocolRelativeString: encodedImage,
                        relativeTo: animeURL
                    ).tryUnwrap(.urlError)
                    
                    return AnimeLink(
                        title: searchEntry.title,
                        link: animeURL,
                        image: animeImage,
                        source: self.parent
                    )
                }
                return searchResults
            } .then {
                results -> [AnimeLink] in
                // No results or last page
                if results.isEmpty {
                    if self.totalPages == nil {
                        throw NineAnimatorError.searchError("No results found")
                    } else { self.totalPages = newPage }
                } else {
                    self.totalPages = newPage + 1
                }
                
                return results
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
                self.performingTask = nil
                self._results.append($0)
                
                self.delegate?.pageIncoming(newPage, from: self)
            }
        }
        
        init(_ query: String, withParent parent: NASourceArrayanime) {
            self.parent = parent
            self.title = query
            self._results = []
        }
    }
    func search(keyword: String) -> ContentProvider {
        SearchAgent(keyword, withParent: self)
    }
}
