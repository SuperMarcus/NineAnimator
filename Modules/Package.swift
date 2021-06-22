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

import PackageDescription

let package = Package(
    name: "NineAnimatorModules",
    platforms: [ .iOS(.v12), .tvOS(.v13), .watchOS(.v7) ],
    products: [
        .library(
            name: "NineAnimatorNativeSources",
            targets: [ "NineAnimatorNativeSources" ]
        ),
        .library(
            name: "NineAnimatorNativeParsers",
            targets: [ "NineAnimatorNativeParsers" ]
        ),
        .library(
            name: "NineAnimatorNativeListServices",
            targets: [ "NineAnimatorNativeListServices" ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/SuperMarcus/NineAnimatorCommon.git",
            .branch("master")
        )
    ],
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
