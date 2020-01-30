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
import SwiftSoup

extension NASourceAnimeUltima {
    class SearchAgent: ContentProvider {
        let query: String
        weak var delegate: ContentProviderDelegate?
        
        // Accessing the search
        var title: String { query }
        var totalPages: Int? = 1
        var availablePages: Int { result == nil ? 0 : 1 }
        var moreAvailable: Bool { result == nil }
        
        // The result of the search
        private var result: [AnyLink]?
        private var searchRequestingTask: NineAnimatorAsyncTask?
        private let parent: NASourceAnimeUltima
        
        func links(on page: Int) -> [AnyLink] {
            guard page == 0, let result = result else { return [] }
            return result
        }
        
        func more() {
            guard searchRequestingTask == nil else { return }
            searchRequestingTask = parent.request(
                browsePath: "/search",
                query: [ "search": query ]
            ) .then {
                [weak self] responseContent -> [AnimeLink]? in
                guard let self = self else { return nil }
                
                var resultingAnime = [AnimeLink]()
                let bowl = try SwiftSoup.parse(responseContent)
                
                // Iterate through the resulting anime
                for resultAnimeContainer in try bowl.select("div.anime-box") {
                    let animeUrlString = try resultAnimeContainer.select("a").attr("href")
                    let animeUrl = try some(URL(string: animeUrlString), or: .urlError)
                    let animeArtworkString = try resultAnimeContainer.select("img").attr("src")
                    let animeArtworkUrl = try some(URL(string: animeArtworkString), or: .urlError)
                    let animeTitle = try resultAnimeContainer.select("span.anime-title").text()
                    
                    // Construct anime link and add to list
                    resultingAnime.append(AnimeLink(
                        title: animeTitle,
                        link: animeUrl,
                        image: animeArtworkUrl,
                        source: self.parent
                    ))
                }
                
                return resultingAnime
            } .error {
                [weak self] error in
                guard let self = self else { return }
                self.searchRequestingTask = nil
                self.delegate?.onError(error, from: self)
            } .finally {
                [weak self] resultingAnimeLinks in
                guard let self = self else { return }
                self.result = resultingAnimeLinks.map { .anime($0) }
                self.searchRequestingTask = nil
                self.delegate?.pageIncoming(0, from: self)
            }
        }
        
        init(_ parent: NASourceAnimeUltima, query: String) {
            self.query = query
            self.parent = parent
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        SearchAgent(self, query: keyword)
    }
}
