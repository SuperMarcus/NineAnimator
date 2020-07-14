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

protocol ModelMigrator {
    /// The input version range that the migrator accepts
    var inputVersionRange: Range<NineAnimatorVersion> { get }
    
    /// The output version of the migrator
    var outputVersion: NineAnimatorVersion { get }
}

// NineAnimator version number.
//
// NineAnimator uses a variant of semvar internally for versioning. Example: `1.2.5 (14)`.
struct NineAnimatorVersion: CustomStringConvertible, Comparable {
    /// Regular expression for parsing nineanimator format semvar.
    static let naSemvarRegex = try! NSRegularExpression(
        pattern: "(\\d+)\\.(\\d+)(?:\\.(\\d+))?\\s+\\((\\d+)\\)",
        options: []
    )
    
    /// Regular expression for parsing nineanimator format semvar.
    static let regularSemvarRegex = try! NSRegularExpression(
        pattern: "(\\d+)\\.(\\d+)(?:\\.(\\d+))?",
        options: []
    )
    
    /// Zero version number.
    static var zero: NineAnimatorVersion {
        .init()
    }
    
    /// Current version number
    static let current = NineAnimatorVersion(
        semvar: NineAnimator.default.version,
        build: NineAnimator.default.buildNumber
    )!
    
    /// Major version number
    var major: Int

    /// Minor version number
    var minor: Int

    /// Patch number
    var patch: Int

    /// Build release number
    var build: Int

    /// Initialize the NineAnimator version with a version string
    init?(string: String) {
        do {
            let matchingResults = try NineAnimatorVersion
                .naSemvarRegex
                .firstMatch(in: string)
                .tryUnwrap(.unknownError("Cannot find matching pattern for input string."))
            self.major = try Int(matchingResults[1])
                .tryUnwrap(.unknownError("Invalid major number"))
            self.minor = try Int(matchingResults[2])
                .tryUnwrap(.unknownError("Invalid minor number"))
            self.patch = Int(matchingResults[3]) ?? 0
            self.build = try Int(matchingResults[4])
                .tryUnwrap(.unknownError("Invalid build number"))
        } catch {
            Log.error("[NineAnimatorVersion] Unable to parse string '%@': %@", string, error)
            return nil
        }
    }
    
    init?(semvar: String, build: Int) {
        do {
            let matchingResults = try NineAnimatorVersion
                .regularSemvarRegex
                .firstMatch(in: semvar)
                .tryUnwrap(.unknownError("Cannot find matching pattern for input string."))
            self.build = build
            self.major = try Int(matchingResults[1])
                .tryUnwrap(.unknownError("Invalid major number"))
            self.minor = try Int(matchingResults[2])
                .tryUnwrap(.unknownError("Invalid minor number"))
            self.patch = Int(matchingResults[3]) ?? 0
        } catch {
            Log.error("[NineAnimatorVersion] Unable to parse string '%@': %@", semvar, error)
            return nil
        }
    }
    
    init(major: Int = 0, minor: Int = 0, patch: Int = 0, build: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.build = build
    }
}

extension NineAnimatorVersion {
    var description: String {
        "\(major).\(minor)\(patch != 0 ? ".\(patch)" : "") \(build)"
    }
    
    static func < (lhs: NineAnimatorVersion, rhs: NineAnimatorVersion) -> Bool {
        lhs.major == rhs.major ?
            lhs.minor == rhs.minor ?
                lhs.patch == rhs.patch ?
                    lhs.build < rhs.build
                : lhs.patch < rhs.patch
            : lhs.minor < rhs.minor
        : lhs.major < rhs.major
    }
}
