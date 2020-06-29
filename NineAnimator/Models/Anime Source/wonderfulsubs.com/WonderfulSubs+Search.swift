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

extension NASourceWonderfulSubs {
    class SearchAgent: ContentProvider {
        private let query: String
        private unowned let parent: NASourceWonderfulSubs
        private var _queryTask: NineAnimatorAsyncTask?
        
        weak var delegate: ContentProviderDelegate?
        
        // Accessing results
        var totalPages: Int? = 1
        var availablePages: Int = 1
        var results: [AnimeLink]?
        var moreAvailable: Bool { results == nil }
        var title: String { query }
        
        func links(on page: Int) -> [AnyLink] {
            results?.map { .anime($0) } ?? []
        }
        
        func more() {
            guard _queryTask == nil, moreAvailable else { return }
            delegate?.onError(
                NineAnimatorError.contentUnavailableError("WonderfulSubs is no longer available on NineAnimator"),
                from: self
            )
        }
        
        init(_ query: String, parent: NASourceWonderfulSubs) {
            self.query = query
            self.parent = parent
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        SearchAgent(keyword, parent: self)
    }
}
