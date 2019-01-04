//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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

class NASearchMasterAnime: ContentProvider {
    static let apiPathSearch = "/api/anime/filter?search=%@&order=score_desc&page=%@"
    
    var query: String
    
    var totalPages: Int?
    
    var availablePages: Int { return _results.count }
    
    var moreAvailable: Bool { return totalPages == nil || _results.count < totalPages! }
    
    weak var delegate: ContentProviderDelegate?
    
    private let _parent: NASourceMasterAnime
    
    private var _lastRequest: NineAnimatorAsyncTask?
    
    private var _results = [[AnimeLink]]()
    
    init(query: String, parent: NASourceMasterAnime) {
        self.query = query
        self._parent = parent
        more()
    }
    
    deinit { _lastRequest?.cancel() }
    
    func animes(on page: Int) -> [AnimeLink] {
        return _results[page]
    }
    
    func more() {
        if _lastRequest == nil && moreAvailable {
            let keyword = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            let path = String(format: NASearchMasterAnime.apiPathSearch, keyword, "\(availablePages + 1)")
            _lastRequest = _parent.request(ajax: path) {
                [weak self] response, _ in
                guard let self = self else { return }
                
                defer { self._lastRequest = nil }
                
                guard let response = response else {
                    self.delegate?.onError(NineAnimatorError.searchError("Did not find any results for \"\(self.query)\". This might suggests a bad network condition or a service issue."), from: self)
                    return
                }
                
                self.totalPages = response["last_page"] as? Int
                
                guard self.totalPages != 0 else {
                    self.delegate?.onError(NineAnimatorError.searchError("Results Error"), from: self)
                    return
                }
                guard let animes = response["data"] as? [NSDictionary] else { return }
                
                let pageResult: [AnimeLink] = animes.compactMap { anime in
                    guard let title = anime["title"] as? String,
                        let slug = anime["slug"] as? String,
                        let posterDict = anime["poster"] as? NSDictionary,
                        let posterName = posterDict["file"] as? String
                        else { return nil }
                    
                    return AnimeLink(
                        title: title,
                        link: self._parent.anime(slug: slug),
                        image: self._parent.poster(file: posterName),
                        source: self._parent
                    )
                }
                
                let newPage = self.availablePages
                self._results.append(pageResult)
                self.delegate?.pageIncoming(newPage, from: self)
            }
        }
    }
}
