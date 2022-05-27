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

extension NASourceZoroAnime {
    class SearchAgent: ContentProvider {
        var title: String
        
        var totalPages: Int?
        var availablePages: Int { loadedResults.count }
        var moreAvailable: Bool { true }
        
        weak var delegate: ContentProviderDelegate?
        
        private var parent: NASourceZoroAnime
        private var performingTask: NineAnimatorAsyncTask?
        private var loadedResults = [[AnyLink]]()
        
        func links(on page: Int) -> [AnyLink] {
            (0..<loadedResults.count).contains(page) ? loadedResults[page] : []
        }
        
        func more() {
            guard performingTask == nil else { return }
            
            let parent = self.parent
            let keywords = self.title
            let requestingPage = self.loadedResults.count + 1
                        
            performingTask = parent.requestManager.request(
                    "search",
                    handling: .browsing,
                    query: [
                        "keyword": keywords,
                        "page": requestingPage
                    ]
                ) .responseBowl .then {
                bowl -> [AnyLink] in
                try bowl.select(".film_list-wrap > .flw-item").map {
                    item in
                    let artworkLinkString = try item.select(".film-poster > img").attr("data-src")
                    let artworkLink = try URL(
                        protocolRelativeString: artworkLinkString,
                        relativeTo: parent.endpointURL
                    ).tryUnwrap()
                    let animeTitleElement = try item.select(".film-name > a")
                    let animePageLink = try URL(
                        protocolRelativeString: animeTitleElement.attr("href"),
                        relativeTo: parent.endpointURL
                    ).tryUnwrap()
                    let animeTitle = try animeTitleElement.text()
                    
                    return AnimeLink(
                        title: animeTitle,
                        link: animePageLink,
                        image: artworkLink,
                        source: parent
                    )
                } .map { .anime($0) }
            } .defer {
                [weak self] _ in self?.performingTask = nil
            } .error {
                [weak self] error in
                guard let self = self else { return }
                self.delegate?.onError(error, from: self)
            } .finally {
                [weak self] links in
                guard let self = self else { return }
                self.loadedResults.append(links)
                self.delegate?.pageIncoming(requestingPage - 1, from: self)
            }
        }
        
        init(_ query: String, withParent parent: NASourceZoroAnime) {
            self.parent = parent
            self.title = query
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        SearchAgent(keyword, withParent: self)
    }
}
