//
//  AnimeHub+Search.swift
//  NineAnimator
//
//  Created by Uttiya Dutta on 2020-08-07.
//  Copyright © 2020 Marcus Zhou. All rights reserved.
//

import Foundation
import SwiftSoup

extension NASourceAnimeHub {
    class SearchAgent: ContentProvider {
        var title: String

        var totalPages: Int? { 1 }
        var availablePages: Int { _results == nil ? 0 : 1 }
        var moreAvailable: Bool { _results == nil }

        weak var delegate: ContentProviderDelegate?
        private var parent: NASourceAnimeHub
        private var performingTask: NineAnimatorAsyncTask?
        private var _results: [AnimeLink]?

        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        
        func more() {
            if performingTask == nil {
                // Animehub includes the search title in the URL path, rather than as a URL query param.
                let encodedTitle = self.title.replacingOccurrences(of: " ", with: "+")
                
                performingTask = parent.requestManager.request(
                    "/search/\(encodedTitle)",
                    handling: .browsing
                ).responseString.then {
                    [parent] responseContent -> [AnimeLink]? in
                    try SwiftSoup.parse(responseContent)
                        .select("ul.ulclear.grid-item > li").compactMap {
                            animeContainer -> AnimeLink? in
                            let animeArtworkURL = try URL(
                                string: animeContainer.select("a.thumb > img").attr("src")
                            ) ?? NineAnimator.placeholderArtworkUrl
                            
                            let animeLink = try URL(
                                string: animeContainer.select("a.thumb").attr("href")
                            ).tryUnwrap(NineAnimatorError.urlError)
                            
                            let animeTitle = try animeContainer.select("a.thumb").attr("title")
                            
                            return AnimeLink(
                                title: animeTitle,
                                link: animeLink,
                                image: animeArtworkURL,
                                source: parent
                            )
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
        
        init(_ query: String, withParent parent: NASourceAnimeHub) {
            self.parent = parent
            self.title = query
        }
    }
}
