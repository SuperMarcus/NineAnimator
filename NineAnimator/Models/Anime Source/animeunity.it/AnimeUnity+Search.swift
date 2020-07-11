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
        var id: Int
        var title: String
        var imageurl: String
        var slug: String
    }
    private struct DummyCodable: Codable {}
    struct SearchResponse: Codable {
        var to_array: [SearchResponseRecords]
        init(from decoder: Decoder) throws {
            var to_array = [SearchResponseRecords]()
            var container = try decoder.unkeyedContainer()
            while !container.isAtEnd {
                if let route = try? container.decode(SearchResponseRecords.self) {
                    to_array.append(route)
                } else {
                    _ = try? container.decode(DummyCodable.self) // <-- TRICK
                }
            }
            self.to_array = to_array
        }
    }
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
                //let endpointUrl = self.parent.endpointURL
                self.requestTask = self.parent
                    .requestManager
                    .request( // Use relative urls whenever possible so it's easier to deal with endpoint changes
                        "/archivio",
                        query: [ "title": title ]
                    )
                    .responseData
                    .then {
                        [weak self] responseContent -> [AnimeLink] in
                        guard let self = self else {
                            throw NineAnimatorError.unknownError
                        }
                        let data = responseContent
                        let utf8Text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                        let  bowl = try SwiftSoup.parse(utf8Text)
                        var encoded = try bowl.select("archivio").attr("records")
                        encoded = encoded.replacingOccurrences(of: "\n", with: "")
                        let data_json = encoded.data(using: .utf8)!
                        let decoder = JSONDecoder.init()
                        let user: SearchResponse = try decoder.decode(SearchResponse.self, from: data_json)
                        let decodedResponse = user
                        return try decodedResponse.to_array.map {
                            record -> AnimeLink in
                            let link = "https://animeunity.it/anime/"+String(record.id)+"-"+record.slug
                            let animeUrlBuilder = try URLComponents(
                                url: link.asURL(),
                                resolvingAgainstBaseURL: true
                            ).tryUnwrap()
                            return AnimeLink(
                                title: record.title,
                                link: try animeUrlBuilder.url.tryUnwrap(),
                                image: try record.imageurl.asURL(),
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
