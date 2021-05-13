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

// MARK: - Home Integration settings
public extension NineAnimatorUser {
    /// Configure NineAnimator to only run HomeKit tasks when the video is
    /// playing on external screens.
    var homeIntegrationRunOnExternalPlaybackOnly: Bool {
        get {
            if let storedValue = _freezer.value(forKey: Keys.homeExternalOnly) as? Bool {
                return storedValue
            }
            return true
        }
        set { _freezer.set(newValue, forKey: Keys.homeExternalOnly) }
    }
    
    /// The UUID of the "Starts" action set (An action set is a Scene in the Home app)
    var homeIntegrationStartsActionSetUUID: UUID? {
        get {
            if let uuidString = _freezer.string(forKey: Keys.homeUUIDStart) {
                return UUID(uuidString: uuidString)
            }
            return nil
        }
        set { _freezer.set(newValue?.uuidString, forKey: Keys.homeUUIDStart) }
    }
    
    /// The UUID of the "Ends" action set (An action set is a Scene in the Home app)
    var homeIntegrationEndsActionSetUUID: UUID? {
        get {
            if let uuidString = _freezer.string(forKey: Keys.homeUUIDEnd) {
                return UUID(uuidString: uuidString)
            }
            return nil
        }
        set { _freezer.set(newValue?.uuidString, forKey: Keys.homeUUIDEnd) }
    }
}
