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

/// A non-generic protocol for the promise
public protocol NineAnimatorPromiseProtocol {
    /// True if this promise has been resolved or rejected
    var isResolved: Bool { get }
    
    /// True if an error had occurred and this promise is rejected
    var isRejected: Bool { get }
    
    /// Execute the promise immedietly
    func concludePromise()
}

/// NineAnimator's implementation of promise
///
/// Since NineAnimator is involved in many chainned networking stuff,
/// which, as many can tell, creates numerous "callback hells" in the
/// code, and that Marcus couldn't come up with which promise
/// framework to use, so he's just going to write one himself.
public class NineAnimatorPromise<ResultType>: NineAnimatorAsyncTask, NineAnimatorPromiseProtocol, Hashable {
    /// Hold reference to the task
    private var referenceTask: NineAnimatorAsyncTask?
    
    /// Mark the promise as being resolved (success or failiure). A promise can only be resolved once.
    public private(set) var isResolved = false
    
    /// A flag to mark if this promise has been rejected
    public private(set) var isRejected = true
    
    /// Storing the result
    private(set) var result: Result<ResultType, Error>?
    
    private var chainedPromiseCallback: ((ResultType) -> Void)? {
        didSet {
            // If the promise has been resolved
            if let result = result, case let .success(value) = result {
                chainedPromiseCallback?(value)
            }
        }
    }
    
    private var chainedErrorCallback: ((Error) -> Void)? {
        didSet {
            if let result = result, case let .failure(error) = result {
                chainedErrorCallback?(error)
            }
        }
    }
    
    private var deferBlock: ((NineAnimatorPromise<ResultType>) -> Void)? {
        didSet {
            // Run the defer block immedietly if the promise has been resolved
            if isResolved { deferBlock?(self) }
        }
    }
    
    /// Keep a reference to the previous promise
    private var chainedReference: (NineAnimatorAsyncTask & NineAnimatorPromiseProtocol)?
    
    /// The DispatchQueue in which the task and the subsequent
    /// promises will run in
    private var queue: DispatchQueue
    
    /// Additional flags to be passed to the execusion of blocks
    private var queueFlags: DispatchWorkItemFlags
    
    /// The latest DispatchTime that the resolvers can be set
    private var creationDate: DispatchTime = .now()
    
    /// The task to perform when the promise concludes setup
    private var task: NineAnimatorPromiseInitialTask?
    
    /// Thread safety
    private var semaphore: DispatchSemaphore
    
    public typealias NineAnimatorPromiseCallback = NineAnimatorCallback<ResultType>
    public typealias NineAnimatorPromiseInitialTask = (@escaping NineAnimatorPromiseCallback) -> NineAnimatorAsyncTask?
    
    /// Create a new promise in the DispatchQueue with a
    /// classic NineAnimator callback task
    public init(queue: DispatchQueue = .global(qos: .utility), _ task: NineAnimatorPromiseInitialTask?) {
        // Execute the promise task in the DispatchQueue if there is one
        self.queue = queue
        self.task = task
        self.semaphore = DispatchSemaphore(value: 1)
        self.queueFlags = []
    }
    
    /// Resolve the promise with value
    ///
    /// This method is thread safe
    public func resolve(_ value: ResultType) {
        // Atomicy
        semaphore.wait()
        
        defer {
            releaseAll()
            semaphore.signal()
        }
        
        // Check if the promise has been resolved
        guard !isResolved || result != nil else {
            Log.error("[NineAnimatorPromise] Attempting to resolve a promise twice.")
            return
        }
        
        // Store the result
        result = .success(value)
        
        defer {
            isResolved = true
            isRejected = false
        }
        
        // Run the defer block
        deferBlock?(self)
        
        if let resolver = chainedPromiseCallback {
            // Runs the handler in another tick
            queue.async(flags: queueFlags) { resolver(value) }
        } else { Log.error("[NineAnimatorPromise] Promise has no resolver") }
    }
    
    /// Reject the promise with error
    ///
    /// This method is thread safe
    public func reject(_ error: Error) {
        // Atomicy
        semaphore.wait()
        defer { semaphore.signal() }
        
        // Release references after reject
        defer { releaseAll() }
        
        // Check if the promise has been resolved
        guard !isResolved || result != nil else {
            Log.error("[NineAnimatorPromise] Attempting to resolve a promise twice.")
            return
        }
        
        // Store the error
        result = .failure(error)
        
        defer {
            isResolved = true
            isRejected = true
        }
        
        // Run the defer block
        deferBlock?(self)
        
        if let handler = chainedErrorCallback {
            // Runs the handler in another tick
            queue.async(flags: queueFlags) {
                handler(error)
            }
        } else {
            Log.error("[NineAnimatorPromise] Promise is resolved with an error before an error handler is set.")
            Log.error(error)
        }
    }
    
    /// Specify the next chained action for the promise and return
    /// a new promise
    ///
    /// Error is chained with the new promise if no error handler
    /// is set for the current one
    public func then<NextResultType>(_ nextFunction: @escaping (ResultType) throws -> NextResultType?) -> NineAnimatorPromise<NextResultType> {
        let promise = NineAnimatorPromise<NextResultType>(queue: self.queue, nil)
        promise.chainedReference = self // Store our reference to the chained promise
        
        // Set resolve callback
        chainedPromiseCallback = {
            [weak promise] result in
            guard let promise = promise else { return }
            do {
                if let nextResult = try nextFunction(result) {
                    promise.resolve(nextResult)
                } else { promise.reject(NineAnimatorError.unknownError) }
            } catch { promise.reject(error) }
        }
        
        // Pass on the error if no handler is set
        if chainedErrorCallback == nil {
            chainedErrorCallback = {
                [weak promise] error in
                guard let promise = promise else { return }
                promise.reject(error)
            }
        }
        
        return promise
    }
    
    /// Switch the dispatch queue for the handlers
    public func dispatch(on queue: DispatchQueue, flags: DispatchWorkItemFlags = []) -> NineAnimatorPromise<ResultType> {
        let nextPromise = then { $0 }
        nextPromise.queue = queue
        nextPromise.queueFlags = flags
        return nextPromise
    }
    
    /// Pass the result of the promise into another function, which generates
    /// another promise to be chained on.
    public func thenPromise<NextResultType>(_ nextPromise: @escaping (ResultType) throws -> NineAnimatorPromise<NextResultType>?) -> NineAnimatorPromise<NextResultType> {
        let untilThenPromise = NineAnimatorPromise<NextResultType>(queue: self.queue, nil)
        untilThenPromise.chainedReference = self
        
        chainedPromiseCallback = {
            [weak untilThenPromise] result in
            guard let untilThenPromise = untilThenPromise else { return }
            do {
                if let promise = try nextPromise(result) {
                    // Run the promise and save the reference in the
                    // referenceTask (NOT chainedReference)
                    untilThenPromise.referenceTask =  promise
                        .error(untilThenPromise.reject)
                        .finally(untilThenPromise.resolve)
                    // Set chained reference to nil so the current promise
                    // is released
                    untilThenPromise.chainedReference = nil
                } else { untilThenPromise.reject(NineAnimatorError.unknownError) }
            } catch { untilThenPromise.reject(error) }
        }
        
        // Pass on the error if no handler is set
        if chainedErrorCallback == nil {
            chainedErrorCallback = {
                [weak untilThenPromise] error in
                untilThenPromise?.reject(error)
            }
        }
        
        return untilThenPromise
    }
    
    /// Add a statement to the promise that is guarenteed to be executed after this promise concludes
    ///
    /// The defer block is invoked by the `resolve(_:)` or `reject(_:)` function
    public func `defer`(_ deferBlock: @escaping (NineAnimatorPromise<ResultType>) -> Void) -> NineAnimatorPromise<ResultType> {
        if self.deferBlock != nil {
            Log.error("[NineAnimatorPromise] Attempting to add multiple defer blocks. Only the last added block will be executed.")
        }
        self.deferBlock = deferBlock
        return self
    }
    
    /// Concludes the promise
    ///
    /// Promise is not executed until finally is called
    public func finally(_ finalFunction: @escaping (ResultType) -> Void) -> NineAnimatorAsyncTask {
        if chainedErrorCallback == nil {
            Log.error("[NineAnimatorPromise] Concluding a promise without an error handler. This is dangerous.")
        }
        
        // Save callback and conclude the promise
        chainedPromiseCallback = finalFunction
        concludePromise()
        
        return self
    }
    
    /// Catches errors
    public func error(_ handler: @escaping (Error) -> Void) -> NineAnimatorPromise {
        chainedErrorCallback = handler
        return self
    }
    
    /// Cancel the underlying NineAnimatorAsyncTask
    ///
    /// This method is thread safe
    public func cancel() {
        // Atomicy
        guard semaphore.wait(timeout: .now() + .microseconds(50)) == .success else {
            return Log.error("[NineAnimatorPromise] Unable to cancel a task because it's being occupied.")
        }
        defer { semaphore.signal() }
        
        // Cancel the reference task and release the promise
        referenceTask?.cancel()
        releaseAll()
    }
    
    /// Release references to all holding objects
    ///
    /// - Important: Calling this method won't release the result of the promise.
    ///              Make sure the result doesn't reference the promise.
    private func releaseAll() {
        referenceTask = nil
        chainedPromiseCallback = nil
        chainedErrorCallback = nil
        chainedReference = nil
        deferBlock = nil
        isResolved = true
    }
    
    /// Conclude the setup of promise and start the task
    public func concludePromise() {
        // Tell the previous promise to conclude first
        if let previous = chainedReference {
            previous.concludePromise()
        }
        
        // Run the initial task
        if let task = task {
            queue.async(flags: queueFlags) {
                [weak self] in
                guard let self = self else {
                    Log.error("[NineAnimatorPromise] Reference to promise lost before the initial task can run")
                    return
                }
                // Save the reference created by the task
                self.referenceTask = task {
                    [weak self] result, error in
                    if let result = result {
                        self?.resolve(result)
                    } else { self?.reject(error ?? NineAnimatorError.providerError("Unknown Error")) }
                }
            }
        }
    }
    
    /// Make a promise with a closure that will be executed asynchronously
    /// in the speicified queue
    public static func firstly(queue: DispatchQueue = .global(), _ executingFunction: @escaping () throws -> ResultType?) -> NineAnimatorPromise {
        NineAnimatorPromise(queue: queue) {
            callback in
            do {
                if let result = try executingFunction() {
                    callback(result, nil)
                } else { throw NineAnimatorError.unknownError }
            } catch { callback(nil, error) }
            return nil
        }
    }
    
    deinit {
        if !isResolved {
            Log.debug("[NineAnimatorPromise] Losing reference to an unresolved promise. This cancels any executing tasks.")
        }
        cancel()
    }
}
