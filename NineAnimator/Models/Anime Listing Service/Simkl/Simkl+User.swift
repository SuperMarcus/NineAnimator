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

extension Simkl {
    struct User: Codable {
        var name: String
    }
    
    func currentUser() -> NineAnimatorPromise<User> {
        return apiRequest("/users/settings", expectedResponseType: NSDictionary.self).then {
            try DictionaryDecoder().decode(UserSettingsResponse.self, from: $0).user
        }
    }
}

// MARK: - Data Caching
extension Simkl {
    var cachedUserCollections: [String: Collection]? {
        get {
            do {
                if let encodedCache = persistedProperties[PersistedKeys.cachedCollections] as? Data {
                    return try PropertyListDecoder().decode(
                        [String: Collection].self,
                        from: encodedCache
                    )
                }
            } catch { Log.error("[Simkl.com] Unable to decode the cached user collections (%@), returning nil instead", error) }
            return nil
        }
        set {
            do {
                persistedProperties[PersistedKeys.cachedCollections] = try {
                    if let newValue = newValue {
                        return try PropertyListEncoder().encode(newValue)
                    } else { return nil }
                }()
            } catch { Log.error("[Simkl.com] Unable to persist cached user collections: %@", error) }
        }
    }
    
    var cachedUserCollectionsLastUpdate: Date {
        get { return persistedProperties[PersistedKeys.cacheLastUpdateDate] as? Date ?? .distantPast }
        set { persistedProperties[PersistedKeys.cacheLastUpdateDate] = newValue }
    }
}
