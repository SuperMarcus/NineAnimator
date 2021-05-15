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

extension NASourceAnimeTwist {
    class TwistContentProvider: ContentProvider {
        var title: String
        
        var totalPages: Int? = 1
        
        var availablePages: Int = 1
        
        var moreAvailable: Bool = false
        
        weak var delegate: ContentProviderDelegate?
        
        private unowned var parent: NASourceAnimeTwist
        
        private var loadingTask: NineAnimatorAsyncTask?
        
        private var results: [AnimeLink]?
        
        func links(on page: Int) -> [AnyLink] {
            results?.map { .anime($0) } ?? []
        }
        
        // swiftlint:disable closure_end_indentation
        func more() {
            guard results == nil else { return }
            loadingTask = parent.listedAnimePromise.then {
                [weak self] list -> [AnimeLink]? in
                guard let self = self else { return nil }
                return list
                    .filter { $0.title.localizedCaseInsensitiveContains(self.title) }
                    .map(self.parent.anime)
            } .then {
                [weak self] list -> [AnimeLink]? in
                guard let self = self else { return nil }
                guard !list.isEmpty else {
                    throw NineAnimatorError.searchError("No results found for \"\(self.title)\"")
                }
                return list
            } .error {
                [weak self] in
                guard let self = self else { return }
                self.delegate?.onError($0, from: self)
            } .finally {
                [weak self] in
                guard let self = self else { return }
                self.results = $0
                self.delegate?.pageIncoming(0, from: self)
            }
        }
        // swiftlint:enable closure_end_indentation
        
        init(_ query: String, parent: NASourceAnimeTwist) {
            self.parent = parent
            self.title = query
        }
    }
    
    func search(keyword: String) -> ContentProvider {
        TwistContentProvider(keyword, parent: self)
    }
}
