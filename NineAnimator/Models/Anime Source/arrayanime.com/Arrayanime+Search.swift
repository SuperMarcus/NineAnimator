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

        var totalPages: Int? { 1 } // Unknown no. of pages
        var availablePages: Int { _results == nil ? 0 : 1 }
        var moreAvailable: Bool { _results == nil }
        
        weak var delegate: ContentProviderDelegate?
        private var parent: NASourceArrayanime
        private var performingTask: NineAnimatorAsyncTask?
        private var _results: [AnimeLink]?
        
        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        
        func more() {
            guard performingTask == nil else { return }
            // Arrayanime includes the search title in the URL path, hence need to encode
            let encodedTitle = self.title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            
            performingTask = parent.requestManager.request(
                parent.vercelEndpoint.absoluteString + "/search/\(encodedTitle ?? "")/1",
                handling: .default
            ) .responseDecodable(type: SearchResponse.self).then {
                searchResponse -> [AnimeLink] in
                let searchResults = try searchResponse.results.map {
                    searchEntry -> AnimeLink in
                    
                    let originalString = self.parent.vercelEndpoint.absoluteString + "/details/\(searchEntry.id)"
                    let encodedLink = try originalString
                        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                        .tryUnwrap(.urlError)
                    
                    let encodedImage = try searchEntry.image
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) // Thanks uttiya
                    .tryUnwrap(.urlError)
                    
                    let animeURL = try URL(string: encodedLink).tryUnwrap(.urlError)
                    let animeImage = try URL(string: encodedImage).tryUnwrap(.urlError)
                    
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
