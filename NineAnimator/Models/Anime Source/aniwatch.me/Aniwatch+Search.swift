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

extension NASourceAniwatch {
    class SearchAgent: ContentProvider {
        var title: String

        var totalPages: Int? { 1 }
        var availablePages: Int { _results == nil ? 0 : 1 }
        var moreAvailable: Bool { _results == nil }

        weak var delegate: ContentProviderDelegate?
        private var parent: NASourceAniwatch
        private var performingTask: NineAnimatorAsyncTask?
        private var _results: [AnimeLink]?

        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        
        /*lazy var searchParameters: [String: Any] = [
            "action": "search",
            "animelist": [2],
            "anyGenre": false,
            "anyStaff": false,
            "anyTag": false,
            "controller": "Search",
            "genre": "[]",
            "hasRelation": false,
            "langs": [],
            "maxEpisodes": 0,
            "order": "title",
            "rOrder": false,
            "staff": "[]",
            "status": [0],
            "tags": [],
            "typed": self.title,
            "types": [0],
            "yearRange": [
                1965,
                // Two years from now
                Calendar.current.component(.year, from: Date()) + 2
            ]
        ]
        
        fileprivate struct AniwatchSearchEntry: Decodable {
            let cover: String
            let title: String
            let detail_id: Int
        }*/
        
        func more() {
            /*if performingTask == nil {
                performingTask = parent.requestManager.request(
                    parent.ajexEndpoint.absoluteString,
                    handling: .default,
                    method: .post,
                    parameters: searchParameters,
                    encoding: JSONEncoding(),
                    headers: [ "x-path": "/search" ]
                ).responseDecodable(type: [AniwatchSearchEntry].self).then {
                    searchEntries -> [AnimeLink] in
                    let searchResults = try searchEntries.map {
                        searchEntry -> AnimeLink in
                        
                        let animeLink = try URL(string: self.parent.endpoint + "/anime/\(searchEntry.detail_id)").tryUnwrap(.urlError)
                        
                        let animeImage = try URL(string: searchEntry.cover).tryUnwrap(.urlError)
                        
                        return AnimeLink(
                            title: searchEntry.title,
                            link: animeLink,
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
            }*/
        }
        init(_ query: String, withParent parent: NASourceAniwatch) {
            self.parent = parent
            self.title = query
        }
    }
    func search(keyword: String) -> ContentProvider {
        SearchAgent(keyword, withParent: self)
    }
}
