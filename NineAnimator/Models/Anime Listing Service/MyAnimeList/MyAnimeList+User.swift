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

extension MyAnimeList {
    struct User {
        let identifier: Int
        let name: String
        
        init(_ userEntry: NSDictionary) throws {
            identifier = try userEntry.value(at: "id", type: Int.self)
            name = try userEntry.value(at: "name", type: String.self)
        }
    }
    
    func currentUser() -> NineAnimatorPromise<User> {
        return apiRequest("/users/@me").then {
            response in
            guard let firstObject = response.data.first else {
                throw NineAnimatorError.responseError("User object not found")
            }
            return try User(firstObject)
        }
    }
}
