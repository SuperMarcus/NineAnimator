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

public extension NineAnimatorPromise {
    /// Execute a list of promises in series
    ///
    /// `NineAnimatorPromise.queue` is like `NineAnimatorPromise.all` except
    /// the promised tasks are executed in series instead of concurrently
    static func queue<GroupedResultType>(
            queue: DispatchQueue = .global(),
            listOfPromises promises: [NineAnimatorPromise<GroupedResultType>]
        ) -> NineAnimatorPromise<[GroupedResultType]> {
        NineAnimatorPromise<[GroupedResultType]>(queue: queue) {
            callback in
            var mutableQueue = promises
            var results = [GroupedResultType]()
            let taskPool = AsyncTaskContainer()
            
            func executeNext() {
                if mutableQueue.isEmpty {
                    callback(results, nil)
                } else {
                    taskPool.add(mutableQueue.removeFirst().error {
                        callback(nil, $0)
                    } .finally {
                        results.append($0)
                        executeNext()
                    })
                }
            }
            
            executeNext()
            return taskPool
        }
    }
}
