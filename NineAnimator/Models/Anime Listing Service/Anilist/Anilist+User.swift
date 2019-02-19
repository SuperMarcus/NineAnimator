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

extension Anilist {
    struct User {
        let id: Int
        let name: String
        let siteUrl: URL
    }
    
    func currentUser() -> NineAnimatorPromise<User> {
        // Return the cached user if it exists
        if let cachedUser = _currentUser {
            return NineAnimatorPromise.firstly { cachedUser }
        }
        
        return graphQL(fileQuery: "AniListUser", variables: [:])
            .then {
                results -> User in
                guard let id = results.value(forKeyPath: "Viewer.id") as? Int,
                    let name = results.value(forKeyPath: "Viewer.name") as? String,
                    let siteUrlString = results.value(forKeyPath: "Viewer.siteUrl") as? String,
                    let siteUrl = URL(string: siteUrlString) else {
                    throw NineAnimatorError.responseError("Cannot find all entries required for the response")
                }
                return User(id: id, name: name, siteUrl: siteUrl)
            } .then {
                [unowned self] in
                self._currentUser = $0
                return $0
            }
    }
}
