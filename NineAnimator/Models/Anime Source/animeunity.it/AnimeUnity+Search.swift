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

extension NASourceAnimeUnity {
    class SearchAgent: ContentProvider {
        var totalPages: Int? { 1 }
        var availablePages: Int { _results == nil ? 0 : 1 }
        var moreAvailable: Bool { _results == nil }
        private let parent: NASourceAnimeUnity
        private var requestTask: NineAnimatorAsyncTask?
        private var _results: [AnimeLink]?
        private var anno: [AnimeLink]?
        private var _results_not: [AnimeLink]?
        var Year: [Int] = []
        var title: String
        var returned = true
        weak var delegate: ContentProviderDelegate?
        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        func more() {
            if self.returned {
                self.returned = false
                let params: Parameters = ["query": title]
                let url = "https://animeunity.it/anime.php?c=archive"
                let request = self.parent.browseSession.request(url, method: .post, parameters: params)
                self.parent.applyMiddlewares(to: request).responseData {
                    [weak self] response in
                    guard let self = self else { return }
                    do {
                        let bowl = try SwiftSoup.parse(response.debugDescription)
                        let entries = try bowl.select("div.row>div.col-lg-4")
                        self._results_not = try entries.compactMap {
                            entry -> AnimeLink? in
                            let animeTitle = try entry.select("div>h6.card-title>b")
//                          detect the "realease year" and save it into Year array
                            var year_ex = 0
                            let anno2 = try entry.select("div.card-block>p.card-text").text()
                            if anno2.contains("Anno di uscita:") {
                                let anno = anno2.components(separatedBy: "Anno di uscita: ")
                                year_ex = Int(anno[1]) ?? 0
                            }
                            self.Year.append(year_ex)
                            let title = try animeTitle.text()
                            if title.isEmpty { return nil }
                            let animeLinkPath = try entry.select("div>a")
                            let url = try animeLinkPath.attr("href")
                            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
                            let animeArtworkPath = try entry.select("img").attr("src")
                            guard let animeUrl = URL(string: "https://animeunity.it/" + trimmed),
                                let coverImage = URL(string: animeArtworkPath)
                                else {
                                return nil
                            }
                            return AnimeLink(
                                title: title,
                                link: animeUrl,
                                image: coverImage,
                                source: self.parent
                            )
                        }
                        self._results = zip(self.Year, self._results_not ?? []).sorted { $0.0 < $1.0 }.map { $0.1 }
                        self.delegate?.pageIncoming(0, from: self)
                    } catch {
                        Log.error("[NASourceAnimeUnity.SearchAgent] Unable to perform search operation: %@", error)
                    }
                }
            }
        }
        init(query: String, parent: NASourceAnimeUnity) {
            self.title = query
            self.parent = parent
        }
    }
    func search(keyword: String) -> ContentProvider {
        SearchAgent(query: keyword, parent: self)
    }
}
