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

extension OfflineContent {
    /// Change the cache strategy of the resources to make AVKit ignore the Cache-Control parameters
    func adjustCacheStrategy(forPackagedResource resourceUrl: URL) {
        let fs = FileManager.default
        let descriptorDirectory = resourceUrl.appendingPathComponent("Data")
        let seekingFileAttributes: Set<URLResourceKey> = [
            .isRegularFileKey
        ]
        var isDirectoryFlag: ObjCBool = false
        guard fs.fileExists(
                atPath: descriptorDirectory.path,
                isDirectory: &isDirectoryFlag
            ), isDirectoryFlag.boolValue else {
            return Log.error(
                "[OfflineContent] Unable to adjust cache strategy for downloaded movie package at '%@'. Is this a valid package? Has the format been changed?",
                resourceUrl.path
            )
        }
        
        guard let descriptorEnumerator = fs.enumerator(
            at: resourceUrl,
            includingPropertiesForKeys: Array(seekingFileAttributes)
        ) else { return Log.error("[OfflineContent] Unable to adjust cache strategy for downloaded movie package at '%@': Unable to create descriptor enumerator.") }
        
        // Enumerate each descriptor file
        for case let descriptor as URL in descriptorEnumerator where descriptor.pathExtension == "descriptor" {
            do {
                // Read and decode the descriptors
                let descriptorData = try Data(contentsOf: descriptor)
                var encodingFormat: PropertyListSerialization.PropertyListFormat = .xml
                var descriptorObject = try (try PropertyListSerialization.propertyList(
                    from: descriptorData,
                    options: [],
                    format: &encodingFormat
                ) as? [String: Any]).tryUnwrap(.decodeError("Unable to decode descriptor"))
                
                // Update cache flags
                descriptorObject["no-cache"] = false
                descriptorObject["must-validate"] = false
                
                // Re-encode and write to the descriptor file
                try PropertyListSerialization.data(
                    fromPropertyList: descriptorObject,
                    format: encodingFormat,
                    options: 0
                ).write(to: descriptor)
                
                Log.debug(
                    "[OfflineContent] Updated descriptor file '%@'",
                    descriptor.path
                )
            } catch {
                Log.error("[OfflineContent] Unable to update descriptor '%@' for movie package. This may impact offline playability.", error.localizedDescription)
            }
        }
    }
}
