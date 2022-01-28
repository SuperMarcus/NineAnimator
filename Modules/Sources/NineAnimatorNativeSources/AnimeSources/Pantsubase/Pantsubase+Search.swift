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
import NineAnimatorCommon

extension NASourcePantsubase {
    class SearchAgent: ContentProvider {
        var title: String
        
        var totalPages: Int? { 1 }
        var availablePages: Int { _results == nil ? 0 : 1 }
        var moreAvailable: Bool { _results == nil }
        
        weak var delegate: ContentProviderDelegate?
        private var parent: NASourcePantsubase
        private var performingTask: NineAnimatorAsyncTask?
        private var _results: [AnimeLink]?
        
        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        
        func more() {/*
            if performingTask == nil {
                performingTask = parent.requestManager.request(
                    url: parent.endpointURL.appendingPathComponent("/search"),
                    query: [ "name": title ]
                ).responseBowl.then {
                    bowl -> [AnimeLink] in
                    let results = try bowl.select("div.anime > .list")
                        .map {
                            item -> AnimeLink in
                            let webLink = try URL(
                                string: item
                                    .select(".itema > .link")
                                    .attr("href")
                            ).tryUnwrap()
                            
                            let animeTitle = try item.select(".itema > .ani-name").text()
                            
                            var animeCover = try item.select(".itema > .link > img").attr("src")
                            
                            // Add https:// prefix if required
                            if animeCover.hasPrefix("//") {
                                animeCover = "https:" + (try animeCover
                                    .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                                    .tryUnwrap(.urlError))
                            }
                            
                            let animeCoverURL = try URL(string: animeCover)
                                .tryUnwrap()
                            
                            return AnimeLink(
                                title: animeTitle,
                                link: webLink,
                                image: animeCoverURL,
                                source: self.parent
                            )
                        }
                    return results
                }
                .then {
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
            }*/
        }
        
        init(_ query: String, withParent parent: NASourcePantsubase) {
            self.parent = parent
            self.title = query
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        SearchAgent(keyword, withParent: self)
    }
}
