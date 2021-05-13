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
    /// Executing a list of promises
    ///
    /// The results are located in the same positions as the tasks that
    /// produced them
    static func all<GroupedResultType>(
            queue: DispatchQueue = .global(),
            listOfPromises promises: [NineAnimatorPromise<GroupedResultType>]
        ) -> NineAnimatorPromise<[GroupedResultType]> {
        // The resulting type is a giant NineAnimatorPromise
        return NineAnimatorPromise<[GroupedResultType]>(queue: queue) {
            [promises] callback in
            var results = [GroupedResultType?](repeating: nil, count: promises.count)
            var isRejected = false
            
            // Use NineAnimatorMultistepAsyncTask to hold references to all the tasks
            let containerTask = AsyncTaskContainer()
            
            // Only reject once. If one task fails, cancel all other tasks
            let rejectOnce: (Error) -> Void = {
                [weak containerTask] error in
                if !isRejected {
                    isRejected = true
                    callback(nil, error)
                    containerTask?.cancel()
                }
            }
            
            // Resolver for index
            let resolve: (Int) -> (GroupedResultType) -> Void = {
                (index: Int) -> (GroupedResultType) -> Void in {
                    (result: GroupedResultType) in
                    guard !isRejected else { return }
                    results[index] = result
                    let resolvedResults = results.compactMap { $0 }
                    if resolvedResults.count == promises.count {
                        callback(resolvedResults, nil)
                    }
                }
            }
            
            // Map the tasks to promises
            promises.enumerated().map {
                index, task in
                let taskPromise = task
                    .error(rejectOnce)
                    .finally(resolve(index))
                return taskPromise
            } .forEach(containerTask.add)
            
            return containerTask
        }
    }
    
    /// Executing a list of tasks
    static func all<GroupedResultType>(
            queue: DispatchQueue = .global(),
            listOfTasks: [() throws -> GroupedResultType?]
        ) -> NineAnimatorPromise<[GroupedResultType]> {
        all(queue: queue, listOfPromises: listOfTasks.map { NineAnimatorPromise<GroupedResultType>.firstly($0) })
    }
    
    /// Alias
    static func all<GroupedResultType>(
            queue: DispatchQueue = .global(),
            _ tasks: (() throws -> GroupedResultType?)...
        ) -> NineAnimatorPromise<[GroupedResultType]> {
        all(queue: queue, listOfTasks: tasks)
    }
    
    /// Alias
    static func all<GroupedResultType>(
            queue: DispatchQueue = .global(),
            promises: NineAnimatorPromise<GroupedResultType>...
        ) -> NineAnimatorPromise<[GroupedResultType]> {
        all(queue: queue, listOfPromises: promises)
    }
}
