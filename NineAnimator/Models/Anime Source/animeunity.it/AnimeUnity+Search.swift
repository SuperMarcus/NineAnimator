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
            var stringa:String!
            private let parent: NASourceAnimeUnity
            private var requestTask: NineAnimatorAsyncTask?
            private var _results: [AnimeLink]?
            var title: String
            
            weak var delegate: ContentProviderDelegate?
            
            func links(on page: Int) -> [AnyLink] {
                page == 0 ? _results?.map { .anime($0) } ?? [] : []
            }
            
            func func_real() {
                
                _ = [
                  "query": title
                ]
                let params: Parameters = ["query":title]
                //let param:[String:Any] = ["c":"archive"]
                let url = "https://animeunity.it/anime.php?c=archive"
                
                _ = AF.request(url, method: .post, parameters:params)
                .responseData { response in
                    self.stringa =  (response.debugDescription)
                   
                }
            }
            
            func more() {
                func_real()
                
                guard requestTask == nil && moreAvailable else { return }
                requestTask = parent.request(
                    browsePath: "/Search/Anime",
                    query: [ "keyword": title ]
                ) .then {
                    [weak self] responseContent -> [AnimeLink] in
                    guard let self = self else { throw NineAnimatorError.unknownError }
                    var str_correct:String?
                    str_correct = self.stringa
                   
                    let bowl = try SwiftSoup.parse(str_correct!)
                    let entries = try bowl.select("div.row>div.col-lg-4")
                    let resultingLinks = entries.compactMap {
                        entry -> AnimeLink? in
                        do {
                            let animeTitle = try entry.select("div>h6.card-title>b"/*"h6.card-title>b"*/)
                            let title = try animeTitle.text()
                            if(title.isEmpty) {return nil}
                            let animeLinkPath = try entry.select("div>a")
                            let url = try animeLinkPath.attr("href")
                            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)

                            let animeArtworkPath = try entry.select("img").attr("src")
                            _ = ""
                            guard let animeUrl = URL(string :"https://animeunity.it/" + trimmed),
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
            
            init(query: String, parent: NASourceAnimeUnity) {
                self.title = query
                self.parent = parent
            }
        }
        
        func search(keyword: String) -> ContentProvider {
            SearchAgent(query: keyword, parent: self)
        }
}
