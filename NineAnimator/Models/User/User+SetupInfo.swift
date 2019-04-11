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

extension NineAnimatorUser {
    /// Store the version of NineAnimator that has been setup
    var setupVersion: String? {
        get { return _freezer.string(forKey: Keys.version) }
        set { _freezer.set(newValue, forKey: Keys.version) }
    }
    
    /// Check if the setup wizard was shown
    var didSetupLatestVersion: Bool {
        return setupVersion == "\(NineAnimator.default.version) (\(NineAnimator.default.buildNumber))"
    }
    
    /// Mark setup as completed
    func markDidSetupLatestVersion() {
        setupVersion = "\(NineAnimator.default.version) (\(NineAnimator.default.buildNumber))"
    }
}
