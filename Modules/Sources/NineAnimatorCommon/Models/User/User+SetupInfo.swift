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

public extension NineAnimatorUser {
    /// Store the version of NineAnimator that has been setup
    var setupVersion: NineAnimatorVersion? {
        get {
            if let versionStrng = _freezer.string(forKey: Keys.version) {
                return NineAnimatorVersion(string: versionStrng)
            }
            
            return nil
        }
        set { _freezer.set(newValue?.stringRepresentation, forKey: Keys.version) }
    }
    
    /// For now, the runtime uuid will reflect the randomly generated UUID at launchtime for privacy reasons
    var runtimeUuid: UUID {
        get {
            var appRuntimeUuid = NineAnimator.applicationRuntimeUuid.uuid
            withUnsafeMutablePointer(to: &appRuntimeUuid.0) {
                uuidPtr in
                var buildPrefix = NineAnimator.runtime.buildPrefixIdentifier
                let buildPrefixHashingId = buildPrefix.removeFirst()
                _ = buildPrefix.reduce(uuidPtr) {
                    ptr, currentValue in
                    ptr.pointee = buildPrefixHashingId ^ currentValue
                    return ptr.advanced(by: 1)
                }
            }
            return UUID(uuid: appRuntimeUuid)
        }
        set { NineAnimator.applicationRuntimeUuid = newValue }
    }
    
    /// Check if the setup wizard was shown
    var didSetupLatestVersion: Bool {
        setupVersion == .current
    }
    
    /// Versions of NineAnimator that are compatible with the current model
    var modelCompatibleVersions: ClosedRange<NineAnimatorVersion> {
        NineAnimatorVersion(major: 1, minor: 2, patch: 7, build: 6)...(.current)
    }
    
    /// A list of ModelMigrators built in to the current version of NineAnimator
    ///
    /// Sorted from oldest to newest. This is the order which the migrators should be executed in
    var builtinMigrators: [ModelMigrator] {
        [
            LegacyUserDefaultsModelMigrator(),
            CachedDownloadsToAppSupportDataMigrator()
        ]
    }
    
    /// Returns all ModelMigrators available to migrate an outdated model
    ///
    /// Sorted from oldest to newest. This is the order which the migrators should be executed in
    /// - Returns: nil if the current version is compatible or if no model migrator is available for the current model version
    func availableModelMigrators() -> [ModelMigrator]? {
        if !didSetupLatestVersion, let modelVersion = setupVersion {
            return builtinMigrators.filter { migrator in
                migrator.inputVersionRange.contains(modelVersion)
            }
        }
        return nil
    }
    
    /// Mark setup as completed
    func markDidSetupLatestVersion() {
        setupVersion = .current
    }
}
