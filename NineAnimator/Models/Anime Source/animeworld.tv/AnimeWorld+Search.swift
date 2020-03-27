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
extension NASourceAnimeWorld {
    class SearchAgent: ContentProvider {
    var totalPages: Int? { 1 }
    var availablePages: Int { _results == nil ? 0 : 1 }
    var moreAvailable: Bool { _results == nil }
    private let parent: NASourceAnimeWorld
    private var requestTask: NineAnimatorAsyncTask?
    private var _results: [AnimeLink]?
    var title: String
    weak var delegate: ContentProviderDelegate?
    func links(on page: Int) -> [AnyLink] {
        page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        func more() {
            guard requestTask == nil && moreAvailable else { return }
            requestTask = parent.request(
                browsePath: "/search",
                query: [ "keyword": title ]
            ) .then {
                [weak self] response -> [AnimeLink] in
                guard let self = self else { throw NineAnimatorError.unknownError }
                let bowl = try SwiftSoup.parse(response)
                let entries = try bowl.select("div.film-list>div.item")
                let resultingLinks = entries.compactMap {
                    entry -> AnimeLink? in
                    do {
                        let animeTitle = try entry.select("a.name"/*"h6.card-title>b"*/)
                        let title = try animeTitle.text()
                        if title.isEmpty { return nil }
                        let animeLinkPath = try entry.select("div>a")
                        let url = try animeLinkPath.attr("href")
                        let animeUrl = try URL(
                            string: url,
                            relativeTo: self.parent.endpointURL
                        ).tryUnwrap()
                        let animeArtworkPath = try entry.select("img").attr("src")
                        guard let coverImage = URL(string: animeArtworkPath)
                        else {
                            return nil
                        }
                        return AnimeLink(
                            title: title,
                            link: animeUrl,
                            image: coverImage,
                            source: self.parent
                        )
                    } catch { return nil }
                }
                guard !resultingLinks.isEmpty else {
                    throw NineAnimatorError.searchError("No results found")
                }
                return resultingLinks
            } .error {
                [weak self] error in
                guard let self = self else { return }
                self.delegate?.onError(error, from: self)
                self.requestTask = nil
            } .finally {
                [weak self] results in
                guard let self = self else { return }
                self._results = results
                self.delegate?.pageIncoming(0, from: self)
                self.requestTask = nil
            }
        }
        init(query: String, parent: NASourceAnimeWorld) {
            self.title = query
            self.parent = parent
        }
    }
    func search(keyword: String) -> ContentProvider {
        SearchAgent(query: keyword, parent: self)
    }
}
