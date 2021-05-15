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

public extension Anilist {
    struct User {
        public let id: Int
        public let name: String
        public let siteUrl: URL
        
        internal let mediaListOptions: GQLMediaListOptions
        
        internal init(_ gqlUser: GQLUser) throws {
            self.id = try gqlUser.id.tryUnwrap()
            self.name = try gqlUser.name.tryUnwrap()
            self.siteUrl = try URL(
                string: try gqlUser.siteUrl.tryUnwrap()
            ).tryUnwrap()
            self.mediaListOptions = try gqlUser.mediaListOptions.tryUnwrap()
        }
    }
    
    func currentUser() -> NineAnimatorPromise<User> {
        // Return the cached user if it exists
        if let cachedUser = _currentUser {
            return NineAnimatorPromise.firstly { cachedUser }
        }
        
        return graphQL(fileQuery: "AniListUser", variables: [:])
            .then {
                response -> User in
                let gqlUserEntry = try response.value(
                    at: "Viewer",
                    type: [String: Any].self
                )
                let gqlUser = try DictionaryDecoder().decode(
                    GQLUser.self,
                    from: gqlUserEntry
                )
                return try .init(gqlUser)
            } .then {
                [unowned self] in
                self._currentUser = $0
                return $0
            }
    }
}
