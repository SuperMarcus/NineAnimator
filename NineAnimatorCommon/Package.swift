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

let package = Package(
    name: "NineAnimatorCommon",
    platforms: [ .iOS("12.3"), .tvOS(.v13), .watchOS(.v7) ],
    products: [
        .library(
            name: "NineAnimatorCommon",
            targets: [ "NineAnimatorCommon" ]
        ),
        .library(
            name: "NineAnimatorNativeSources",
            targets: [ "NineAnimatorNativeSources" ]
        ),
        .library(
            name: "NineAnimatorNativeParsers",
            targets: [ "NineAnimatorNativeParsers" ]
        )
    ],
    dependencies: [
        .package(
            name: "Alamofire",
            url: "https://github.com/Alamofire/Alamofire.git",
            from: "5.4.3"
        ),
        .package(
            name: "SwiftSoup",
            url: "https://github.com/scinfu/SwiftSoup.git",
            from: "2.3.2"
        ),
        .package(
            name: "Kingfisher",
            url: "https://github.com/onevcat/Kingfisher.git",
            from: "6.3.0"
        ),
        .package(
            name: "OpenCastSwift",
            url: "https://github.com/SuperMarcus/OpenCastSwift.git",
            .revision("c1a5994b57c6f33b92cb8bcf87e981783b99cac9")
        ),
        .package(
            name: "AppCenter",
            url: "https://github.com/microsoft/appcenter-sdk-apple.git",
            from: "4.1.1"
        )
    ],
    targets: [
        .target(
            name: "NineAnimatorCommon",
            dependencies: [
                "Alamofire",
                "SwiftSoup",
                "Kingfisher",
                "OpenCastSwift",
                .product(name: "AppCenterCrashes", package: "AppCenter"),
                .product(name: "AppCenterAnalytics", package: "AppCenter")
            ],
            exclude: [
                "Utilities/DictionaryCoding/LICENSE.md",
                "Utilities/DictionaryCoding/README.md"
            ],
            resources: [
                .process("Models/Anime Listing Service/Anilist/GraphQL/Query")
            ]
        ),
        .target(
            name: "NineAnimatorNativeSources",
            dependencies: [
                "Alamofire",
                "SwiftSoup",
                "Kingfisher",
                "NineAnimatorCommon"
            ],
            exclude: []
        ),
        .target(
            name: "NineAnimatorNativeParsers",
            dependencies: [
                "Alamofire",
                "SwiftSoup",
                "Kingfisher",
                "NineAnimatorCommon"
            ],
            exclude: []
        )
    ]
)
