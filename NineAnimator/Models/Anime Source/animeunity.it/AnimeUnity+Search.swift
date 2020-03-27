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
    struct SearchResponseRecords: Codable {
        var animeid: String
        var title: String
        var imageurl: String
    }
    
    struct SearchResponse: Codable {
        var records: [SearchResponseRecords]
    }
    
    class SearchAgent: ContentProvider {
        var totalPages: Int? { 1 }
        var availablePages: Int { _results == nil ? 0 : 1 }
        var moreAvailable: Bool { _results == nil }
        var searchRequestUrl: URL {
            parent.endpointURL.appendingPathComponent("inc/livesearch.php")
        }
        
        private let parent: NASourceAnimeUnity
        private var requestTask: NineAnimatorAsyncTask?
        private var _results: [AnimeLink]?
        
        let title: String
        weak var delegate: ContentProviderDelegate?
        
        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        
        func more() {
            guard requestTask == nil else { return }
            
            let request = self.parent.retriverSession.request(
                searchRequestUrl,
                method: .post,
                parameters: [ "search": title ]
            )
            self.parent.applyMiddlewares(to: request).response {
                [weak self] response in
                guard let self = self else { return }
                
                do {
                    guard let responseValue = response.data else {
                        let error: Error? = (response.error?.underlyingError as? NineAnimatorError) ?? response.error
                        throw error ?? NineAnimatorError.unknownError
                    }
                    
                    let decodedResponse = try JSONDecoder().decode(
                        SearchResponse.self,
                        from: responseValue
                    )
                    
                    self._results = try decodedResponse.records.map {
                        record -> AnimeLink in
                        var animeUrlBuilder = try URLComponents(
                            url: self.parent.endpointURL.appendingPathComponent("anime.php"),
                            resolvingAgainstBaseURL: true
                        ).tryUnwrap()
                        animeUrlBuilder.queryItems = [
                            .init(name: "id", value: record.animeid)
                        ]
                        return AnimeLink(
                            title: record.title,
                            link: try animeUrlBuilder.url.tryUnwrap(),
                            image: try URL(string: record.imageurl).tryUnwrap(),
                            source: self.parent
                        )
                    }
                    
                    self.delegate?.pageIncoming(0, from: self)
                } catch {
                    Log.error("[NASourceAnimeUnity.SearchAgent] Unable to perform search operation: %@", error)
                    self.delegate?.onError(error, from: self)
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
