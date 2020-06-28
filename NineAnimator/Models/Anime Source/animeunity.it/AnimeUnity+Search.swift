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
        
        var title: String
        weak var delegate: ContentProviderDelegate?
        
        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        
        func more() {
            if case .none = self.requestTask {
                let endpointUrl = self.parent.endpointURL
                self.requestTask = self.parent
                    .requestManager
                    .request( // Use relative urls whenever possible so it's easier to deal with endpoint changes
                        "/anime.php?c=archive",
                        method: .post,
                        parameters: [ "query": title ]
                    )
                    .responseString
                    .then {
                        [weak self] responseContent -> [AnimeLink] in
                        guard let self = self else {
                            throw NineAnimatorError.unknownError
                        }
                        
                        let bowl = try SwiftSoup.parse(responseContent)
                        let entries = try bowl.select("div.row>div.col-lg-4")
                        
                        return try entries.compactMap {
                            entry -> AnimeLink? in
                            let animeTitle = try entry.select("div>h6.card-title>b")
                            let title = try animeTitle.text()
                            
                            if title.isEmpty { return nil }
                            
                            let animeLinkPath = try entry.select("div>a")
                            let url = try animeLinkPath.attr("href")
                            let animeLinkURLString = url.trimmingCharacters(in: .whitespacesAndNewlines)
                            let animeArtworkPath = try entry.select("img").attr("src")
                            
                            guard let animeUrl = URL(string: animeLinkURLString, relativeTo: endpointUrl),
                                let coverImage = URL(string: animeArtworkPath, relativeTo: endpointUrl)
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
                    }
                    .dispatch(on: .main)
                    .defer {
                        [weak self] _ in self?.requestTask = nil
                    }
                    .error {
                        [weak self] error in
                        Log.error("[NASourceAnimeUnity.SearchAgent] Unable to perform search operation: %@", error)
                        if let provider = self {
                            provider.delegate?.onError(error, from: provider)
                        }
                    }
                    .finally {
                        [weak self] results in
                        guard let self = self else { return }
                        self._results = results
                        self.delegate?.pageIncoming(0, from: self)
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
