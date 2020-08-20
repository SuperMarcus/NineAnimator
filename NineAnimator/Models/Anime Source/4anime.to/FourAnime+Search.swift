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
import SwiftSoup

extension NASourceFourAnime {
    class SearchAgent: ContentProvider {
        var title: String
        
        var totalPages: Int? { 1 }
        var availablePages: Int { _results == nil ? 0 : 1 }
        var moreAvailable: Bool { _results == nil }
        
        weak var delegate: ContentProviderDelegate?
        private var parent: NASourceFourAnime
        private var performingTask: NineAnimatorAsyncTask?
        private var _results: [AnimeLink]?
        
        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        
        func more() {
            if performingTask == nil {
                performingTask = parent.requestManager.request(
                    url: self.encodedW3CQueryUrl,
                    handling: .browsing,
                    method: .post,
                    parameters: [
                        "asl_active": "1",
                        "p_asl_data": "qtranslate_lang=0&set_intitle=None&customset%5B%5D=anime"
                    ]
                ) .responseString
                  .then {
                    [parent] responseContent -> [AnimeLink]? in
                    let bowl = try SwiftSoup.parse(responseContent)
                    let possibleLinkContainers = try bowl.select("div.container a")
                    return try possibleLinkContainers.reduce(into: [AnimeLink]()) {
                        results, container in
                        if let img = try container.select("img").first() {
                            let artworkURLString = try img.attr("src")
                                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                                .tryUnwrap(.urlError)
                            let artworkUrl = try URL(
                                string: artworkURLString
                            ).tryUnwrap()
                            let animeUrl = try URL(
                                string: try container.attr("href")
                            ).tryUnwrap()
                            let animeTitle = try container
                                .select("div")
                                .text()
                            
                            results.append(.init(
                                title: animeTitle,
                                link: animeUrl,
                                image: artworkUrl,
                                source: parent
                            ))
                        }
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
        
        private var encodedW3CQueryUrl: URL {
            guard var urlBuilder = URLComponents(
                    url: self.parent.endpointURL,
                    resolvingAgainstBaseURL: false
                ) else { return self.parent.endpointURL }
            
            var allowedCharacters = CharacterSet.urlQueryAllowed
            allowedCharacters.remove("+")
            
            let encodedSearchKeywords = (self.title.addingPercentEncoding(
                withAllowedCharacters: allowedCharacters
            ) ?? "").replacingOccurrences(of: "%20", with: "+")
            
            urlBuilder.path = "/"
            urlBuilder.percentEncodedQuery = "s=" + encodedSearchKeywords
            
            return urlBuilder.url ?? self.parent.endpointURL
        }
        
        init(_ query: String, withParent parent: NASourceFourAnime) {
            self.parent = parent
            self.title = query
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        SearchAgent(keyword, withParent: self)
    }
}
