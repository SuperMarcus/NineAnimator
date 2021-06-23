// swift-tools-version:5.3
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
import PackageDescription

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let naCommonDependency: Package.Dependency

if FileManager.default.fileExists(atPath: packageDir.deletingLastPathComponent().appendingPathComponent("Common").path) {
    naCommonDependency = .package(name: "NineAnimatorCommon", path: "../Common")
} else {
    naCommonDependency = .package(
        url: "https://github.com/SuperMarcus/NineAnimatorCommon.git",
        .branch("master")
    )
}

let package = Package(
    name: "NineAnimatorModules",
    platforms: [ .iOS(.v12), .tvOS(.v13), .watchOS(.v7) ],
    products: [
        .library(
            name: "NineAnimatorNativeSources",
            type: .dynamic,
            targets: [ "NineAnimatorNativeSources" ]
        ),
        .library(
            name: "NineAnimatorNativeParsers",
            type: .dynamic,
            targets: [ "NineAnimatorNativeParsers" ]
        ),
        .library(
            name: "NineAnimatorNativeListServices",
            type: .dynamic,
            targets: [ "NineAnimatorNativeListServices" ]
        )
    ],
    dependencies: [ naCommonDependency ],
    targets: [
        .target(
            name: "NineAnimatorNativeSources",
            dependencies: [
                "NineAnimatorCommon"
            ]
        ),
        .target(
            name: "NineAnimatorNativeParsers",
            dependencies: [
                "NineAnimatorCommon"
            ]
        ),
        .target(
            name: "NineAnimatorNativeListServices",
            dependencies: [
                "NineAnimatorCommon"
            ],
            resources: [
                .process("ListServices/Anilist/GraphQL/Query")
            ]
        )
    ]
)
