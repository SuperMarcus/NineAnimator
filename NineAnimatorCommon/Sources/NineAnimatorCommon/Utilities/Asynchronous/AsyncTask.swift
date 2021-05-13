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

/// Generic type for a callback closure
public typealias NineAnimatorCallback<T> = (T?, Error?) -> Void

/// Representing an asynchronized task that can be cancelled
public protocol NineAnimatorAsyncTask: AnyObject {
    func cancel()
}

/// A container class used to hold strong references to the
/// contained NineAnimatorAsyncTask and cancel them when
/// needed.
///
/// ## Thread Safety
/// All the methods within this class are thread safe
public class AsyncTaskContainer: NineAnimatorAsyncTask {
    @AtomicProperty fileprivate var tasks: [NineAnimatorAsyncTask] = []
    @AtomicProperty fileprivate var cancellationHandlers: [(AsyncTaskContainer) -> Void] = []
    
    public init() { }
    
    /// Append a task to the container
    public func add(_ task: NineAnimatorAsyncTask?) {
        if let task = task {
            _tasks.mutate {
                $0.append(task)
            }
        }
    }
    
    /// Append a list of tasks to the container
    public func addAll(_ tasks: [NineAnimatorAsyncTask?]?) {
        if let tasks = tasks {
            _tasks.mutate {
                $0.append(contentsOf: tasks.compactMap { $0 })
            }
        }
    }
    
    /// Add a closure that is called upon the cancellation of the entire `AsyncTaskContainer`
    public func onCancellation(_ cancellationBlock: @escaping (AsyncTaskContainer) -> Void) {
        _cancellationHandlers.mutate {
            $0.append(cancellationBlock)
        }
    }
    
    /// Cancel all the tasks in the container
    public func cancel() {
        cancellationHandlers.forEach { $0(self) }
        _tasks.synchronize {
            $0.forEach { $0.cancel() }
        }
    }
    
    public static func += (left: AsyncTaskContainer, right: NineAnimatorAsyncTask?) {
        left.add(right)
    }
    
    deinit { cancel() }
}

/// A task container that preserves a state property which represents the overall state of the execution
///
/// `StatefulAsyncTaskContainer` is designed for the cases when centralized management of the
/// asynchronous tasks are required (such as background refresh). Instead of executing the promises and
/// handling the errors by your own, you delegate those responsibilities to the `StatefulAsyncTaskContainer`.
///
/// After setting up and executed all the tasks in `StatefulAsyncTaskContainer`, call the `collect()`
/// method to mark the `StatefulAsyncTaskContainer` as complete.
/// The `onFinishCollectingStates` will only be called if the container has been marked as ready for
/// collection.
///
/// - Note: `StatefulAsyncTaskContainer` is a subclass of `AsyncTaskContainer`,
///         but `execute(_:)` and `execute(promiseWithState:)` should be used to execute
///         asynchronous promises in the container instead.
public class StatefulAsyncTaskContainer: AsyncTaskContainer {
    /// Indicates whether all the tasks have been added to the container
    @AtomicProperty public var isReadyForCollection = false
    
    /// The final state of task executions
    @AtomicProperty public var state: TaskState = .unknown
    
    @AtomicProperty private var numberOfStatesContributed: Int = 0
    
    private var didFinishCollectingStates: (StatefulAsyncTaskContainer) -> Void
    
    /// Initiate the `StatefulAsyncTaskContainer` with a state collector closure
    /// - Note: The closure is not called when the task is cancelled
    public init(onFinishCollectingStates: @escaping (StatefulAsyncTaskContainer) -> Void) {
        self.didFinishCollectingStates = onFinishCollectingStates
        super.init()
    }
    
    /// Execute a promise within the container
    public func execute(_ promise: NineAnimatorPromise<Void>) {
        // Check the `isReadyForCollection` flag
        if isReadyForCollection {
            return Log.error("[StatefulAsyncTaskContainer] execute(_:) called after the container has been marked as ready for collection. This promise will not be executed.")
        }
        
        let task = promise.error {
            [weak self] in
            Log.error("[StatefulAsyncTaskContainer] Task finished with error: %@", $0)
            self?.contributeState(.failed)
        } .finally {
            [weak self] in self?.contributeState(.succeeded)
        }
        add(task)
    }
    
    /// Execute a promise within the container and save the `TaskState` it creates
    public func execute(promiseWithState: NineAnimatorPromise<TaskState>) {
        // Check the `isReadyForCollection` flag
        if isReadyForCollection {
            return Log.error("[StatefulAsyncTaskContainer] execute(promiseWithState:) called after the container has been marked as ready for collection. This promise will not be executed.")
        }
        
        let task = promiseWithState.error {
            [weak self] in
            Log.error("[StatefulAsyncTaskContainer] Task finished with error: %@", $0)
            self?.contributeState(.failed)
        } .finally {
            [weak self] in self?.contributeState($0)
        }
        add(task)
    }
    
    /// Contribute to the overall state of the cluster of tasks
    public func contributeState(_ newState: TaskState?) {
        var shouldCallDidFinishCollectingStates = false
        
        // Update states
        _state.mutate {
            if let newState = newState, $0.rawValue < newState.rawValue {
                $0 = newState
            }
            
            // Get the ready for collection flag
            let readyForCollectionFlag = isReadyForCollection
            
            // Make sure the tasks are not changed during this period
            $tasks.synchronize {
                tasks in _numberOfStatesContributed.mutate {
                    $0 += 1
                    shouldCallDidFinishCollectingStates =
                        readyForCollectionFlag && $0 == tasks.count
                }
            }
        }
        
        // Call the did finish handler
        if shouldCallDidFinishCollectingStates {
            didFinishCollectingStates(self)
        }
    }
    
    /// Mark the container as ready for task state collection
    public func collect() {
        var shouldCallDidFinishCollectingStates = false
        
        _state.synchronize {
            _ in // This blocks the execution of `contributeState(_:)`
            shouldCallDidFinishCollectingStates =
                tasks.count == numberOfStatesContributed
            
            // Set the flag
            _isReadyForCollection.mutate {
                // Mark shouldCallDidFinishCollectingStates as false if the
                // isReadyForCollection flag is already true
                shouldCallDidFinishCollectingStates =
                    !$0 && shouldCallDidFinishCollectingStates
                $0 = true
            }
        }
        
        // If tasks has finished before
        if shouldCallDidFinishCollectingStates {
            didFinishCollectingStates(self)
        }
    }
    
    /// Representing the states that are returned as the results of the tasks
    public enum TaskState: Int, CaseIterable {
        case unknown, succeeded, failed
    }
}
