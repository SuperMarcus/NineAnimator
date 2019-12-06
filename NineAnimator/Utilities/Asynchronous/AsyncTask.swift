//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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

/// Representing an asynchronized task that can be cancelled
protocol NineAnimatorAsyncTask: AnyObject {
    func cancel()
}

/// A container class used to hold strong references to the
/// contained NineAnimatorAsyncTask and cancel them when
/// needed.
///
/// ## Thread Safety
/// All the methods within this class are thread safe
class AsyncTaskContainer: NineAnimatorAsyncTask {
    @AtomicProperty fileprivate var tasks: [NineAnimatorAsyncTask] = []
    @AtomicProperty fileprivate var cancellationHandlers: [(AsyncTaskContainer) -> Void] = []
    
    /// Append a task to the container
    func add(_ task: NineAnimatorAsyncTask?) {
        if let task = task {
            _tasks.mutate {
                $0.append(task)
            }
        }
    }
    
    /// Append a list of tasks to the container
    func addAll(_ tasks: [NineAnimatorAsyncTask?]?) {
        if let tasks = tasks {
            _tasks.mutate {
                $0.append(contentsOf: tasks.compactMap { $0 })
            }
        }
    }
    
    /// Add a closure that is called upon the cancellation of the entire `AsyncTaskContainer`
    func onCancellation(_ cancellationBlock: @escaping (AsyncTaskContainer) -> Void) {
        _cancellationHandlers.mutate {
            $0.append(cancellationBlock)
        }
    }
    
    /// Cancel all the tasks in the container
    func cancel() {
        cancellationHandlers.forEach { $0(self) }
        _tasks.synchronize {
            $0.forEach { $0.cancel() }
        }
    }
    
    static func += (left: AsyncTaskContainer, right: NineAnimatorAsyncTask?) {
        left.add(right)
    }
    
    deinit { cancel() }
}

/// A task container that preserves a state property which represents the overall state of the execution
class StatefulAsyncTaskContainer: AsyncTaskContainer {
    @AtomicProperty private(set) var state: TaskState = .unknown
    
    /// Execute a promise and preserve the reference to the async task that it creates
    func execute(_ promise: NineAnimatorPromise<Void>) {
        let task = promise.error {
            [weak self] in
            Log.error("[StatefulAsyncTaskContainer] Task finished with error: %@", $0)
            self?.contributeState(.failed)
        } .finally {
            [weak self] in self?.contributeState(.succeeded)
        }
        add(task)
    }
    
    /// Contribute to the overall state of the cluster of tasks
    func contributeState(_ newState: TaskState?) {
        _state.mutate {
            if let newState = newState, $0.rawValue < newState.rawValue {
                $0 = newState
            }
        }
    }
    
    /// Representing the states that are returned as the results of the tasks
    enum TaskState: Int, CaseIterable {
        case unknown, succeeded, failed
    }
}
