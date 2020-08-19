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
import SwiftSoup

extension NASourceKissanime {
    class SearchAgent: ContentProvider {
        var totalPages: Int? { 1 }
        var availablePages: Int { _results == nil ? 0 : 1 }
        var moreAvailable: Bool { _results == nil }
        
        private let parent: NASourceKissanime
        private var requestTask: NineAnimatorAsyncTask?
        private var _results: [AnimeLink]?
        var title: String
        
        weak var delegate: ContentProviderDelegate?
        
        func links(on page: Int) -> [AnyLink] {
            page == 0 ? _results?.map { .anime($0) } ?? [] : []
        }
        
        func more() {
            delegate?.onError(
                NineAnimatorError.ContentUnavailableError("This source is no longer available."),
                from: self
            )
        }
        
        init(query: String, parent: NASourceKissanime) {
            self.title = query
            self.parent = parent
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        SearchAgent(query: keyword, parent: self)
    }
}
