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

extension NASourceAnimeKisa {
    class SearchAgent: ContentProvider {
        var title: String
        
        var totalPages: Int? { return nil }
        var availablePages: Int { return 0 }
        var moreAvailable: Bool { return false }
        
        weak var delegate: ContentProviderDelegate?
        private var parent: NASourceAnimeKisa
        
        func links(on page: Int) -> [AnyLink] {
            return []
        }
        
        func more() { }
        
        init(_ query: String, withParent parent: NASourceAnimeKisa) {
            self.parent = parent
            self.title = query
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        return SearchAgent(keyword, withParent: self)
    }
}
