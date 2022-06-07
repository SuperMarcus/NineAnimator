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

var packageDependencies = [Package.Dependency]()

// NineAnimatorCommon module
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
packageDependencies.append(
    .package(name: "NineAnimatorCommon", path: "../Common")
)

// NineAnimatorCore module (optional)
let hasCoreServices: Bool
if FileManager.default.fileExists(atPath: packageDir.deletingLastPathComponent().appendingPathComponent("NineAnimatorCore").path) {
    packageDependencies.append(
        .package(name: "NineAnimatorCore", path: "../NineAnimatorCore")
    )
    hasCoreServices = true
} else { hasCoreServices = false }

// if FileManager.default.fileExists(atPath: packageDir.deletingLastPathComponent().appendingPathComponent("Common").path) {
//    naCommonDependency = .package(name: "NineAnimatorCommon", path: "../Common")
// } else {
//    naCommonDependency = .package(
//        url: "https://github.com/SuperMarcus/NineAnimatorCommon.git",
//        .revision("b75d541be940ee41d1a93fc3ebbdd6199069b2d2")
//    )
// }

let package = Package(
    name: "NineAnimatorModules",
    platforms: [ .iOS(.v13), .tvOS(.v13), .watchOS(.v7) ],
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
        ),
        .library(
            name: "NineAnimatorCoreServices",
            type: .dynamic,
            targets: [ "NineAnimatorCoreServices" ]
        )
    ],
    dependencies: packageDependencies,
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
        ),
        .target(
            name: "NineAnimatorCoreServices",
            dependencies: hasCoreServices ? [
                "NineAnimatorCore"
            ] : [ "NineAnimatorCommon" ]
        )
    ]
)
