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

/// This class hosts properties from environment variables. Environment variables can be used to
/// modify NineAnimator runtime behaviors. See
/// [runtime.md](https://nineanimator.marcuszhou.com/docs/runtime.html)
public class NineAnimatorRuntime {
    /// Current process information
    private let processInformation: ProcessInfo = .processInfo
    
    /// Environment variables for the current process
    public var environment: [String: String] {
        processInformation.environment
    }
    
    /// Determine if the setup scene should not be presented during the first launch of the application
    public var isSetupSceneDisabled: Bool {
        environment.keys.contains("NINEANIMATOR_NO_SETUP_SCENE")
    }
    
    /// Determine if animations should be disabled
    public var isAnimationDisabled: Bool {
        environment.keys.contains("NINEANIMATOR_NO_ANIMATIONS")
    }
    
    /// Appearance specified by the environment
    public var overridingAppearanceName: String? {
        environment["NINEANIMATOR_APPEARANCE_OVERRIDE"]
    }
    
    /// Determine if a set of fake playback records and recents should be created for testing purposes
    /// - Note: This property will only be effective for debug builds.
    public var shouldCreateDummyRecords: Bool {
        environment.keys.contains("NINEANIMATOR_CREATE_DUMMY_RECORDS")
    }
    
    /// Prefix environment variable
    public var buildPrefixIdentifier: [UInt8] {
        [ 0xfa, 0x82, 0xbc, 0x70, 0x0f ] /* swiftgen - auto generated */
    }
}
