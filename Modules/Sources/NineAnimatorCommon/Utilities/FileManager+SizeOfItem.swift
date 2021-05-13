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

public extension FileManager {
    /// Obtain the size of the items at a particular path, accounting its children
    func sizeOfItem(atUrl url: URL, queue: DispatchQueue = .global()) -> NineAnimatorPromise<Int> {
        NineAnimatorPromise.firstly(queue: queue) {
            try url.resourceValues(forKeys: [
                .fileAllocatedSizeKey,
                .isDirectoryKey
            ])
        } .thenPromise {
            [weak self] attributes in self?.sizeOfItem(
                atUrl: url,
                queue: queue,
                withAttributes: attributes
            )
        }
    }
    
    fileprivate func sizeOfItem(atUrl url: URL, queue: DispatchQueue = .global(), withAttributes attributes: URLResourceValues) -> NineAnimatorPromise<Int> {
        do {
            if let allocatedSize = attributes.fileAllocatedSize {
                return .success(
                    queue: queue,
                    allocatedSize
                )
            } else if attributes.isDirectory == true {
                let fs = FileManager.default
                let requestingResourceAttributes: Set<URLResourceKey> = [
                    .fileAllocatedSizeKey,
                    .isDirectoryKey
                ]
                let enumerator = try fs.enumerator(
                    at: url,
                    includingPropertiesForKeys: Array(requestingResourceAttributes),
                    options: [ .skipsHiddenFiles ]
                ).tryUnwrap()
                var tasks = [NineAnimatorPromise<Int>]()
                
                for case let item as URL in enumerator {
                    let resourceAttributes = try item.resourceValues(
                        forKeys: requestingResourceAttributes
                    )
                    
                    // Recursively construct the other task
                    if resourceAttributes.isDirectory == true {
                        tasks.append(self.sizeOfItem(
                            atUrl: item,
                            queue: queue,
                            withAttributes: resourceAttributes
                        ))
                    } else if let fileSize = resourceAttributes.fileAllocatedSize {
                        tasks.append(.success(queue: queue, fileSize))
                    }
                }
                
                // Execute tasks sequentially
                return NineAnimatorPromise<[Int]>.queue(
                    queue: queue,
                    listOfPromises: tasks
                ).then { $0.reduce(0, +) }
            } else {
                throw NineAnimatorError.decodeError("Invalid url attributes")
            }
        } catch {
            return .firstly(queue: queue) { throw error }
        }
    }
}
