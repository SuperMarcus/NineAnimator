//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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

private protocol NineAnimatorPromiseProtocol {
    func concludePromise()
}

/// NineAnimator's implementation of promise
///
/// Since NineAnimator is involved in many chainned networking stuff,
/// which, as many can tell, creates numerous "callback hells" in the
/// code, and that Marcus couldn't come up with which promise
/// framework to use, I am just going to write one myself.
class NineAnimatorPromise<ResultType>: NineAnimatorAsyncTask, NineAnimatorPromiseProtocol {
    // Hold reference to the task
    private var referenceTask: NineAnimatorAsyncTask?
    
    // A promise can only be resolved once. This is a flag
    // to make sure of that.
    private(set) var isResolved = false
    
    // A flag to mark if this promise has been rejected
    private(set) var isRejected = true
    
    private var chainedPromiseCallback: ((ResultType) -> Void)?
    
    private var chainedErrorCallback: ((Error) -> Void)?
    
    // Keep a reference to the previous promise
    private var chainedReference: (NineAnimatorAsyncTask & NineAnimatorPromiseProtocol)?
    
    // The DispatchQueue in which the task and the subsequent
    // promises will run in
    private var queue: DispatchQueue
    
    // The latest DispatchTime that the resolvers can be set
    private var creationDate: DispatchTime = .now()
    
    // The task to perform when the promise concludes setup
    private var task: NineAnimatorPromiseInitialTask?
    
    // Thread safety
    private var semaphore: DispatchSemaphore
    
    typealias NineAnimatorPromiseCallback = NineAnimatorCallback<ResultType>
    typealias NineAnimatorPromiseInitialTask = (@escaping NineAnimatorPromiseCallback) -> NineAnimatorAsyncTask?
    
    /// Create a new promise in the DispatchQueue with a
    /// classic NineAnimator callback task
    init(queue: DispatchQueue = .global(), _ task: NineAnimatorPromiseInitialTask?) {
        // Execute the promise task in the DispatchQueue if there is one
        self.queue = queue
        self.task = task
        self.semaphore = DispatchSemaphore(value: 1)
    }
    
    /// Resolve the promise with value
    ///
    /// This method is thread safe
    func resolve(_ value: ResultType) {
        // Atomicy
        semaphore.wait()
        defer { semaphore.signal() }
        
        defer { releaseAll() }
        
        guard !isResolved else {
            Log.error("Attempting to resolve a promise twice.")
            return
        }
        
        defer { isResolved = true }
        
        if let resolver = chainedPromiseCallback {
            // Runs the handler in another tick
            queue.async { resolver(value) }
        } else { Log.error("Promise has no resolver") }
    }
    
    /// Reject the promise with error
    ///
    /// This method is thread safe
    func reject(_ error: Error) {
        // Atomicy
        semaphore.wait()
        defer { semaphore.signal() }
        
        // Release references after reject
        defer { releaseAll() }
        
        guard !isResolved else {
            Log.error("Attempting to resolve a promise twice.")
            return
        }
        
        defer {
            isResolved = true
            isRejected = true
        }
        
        if let handler = chainedErrorCallback {
            // Runs the handler in another tick
            queue.async { handler(error) }
        } else {
            Log.error("No rejection handler declared for this promise")
            Log.error(error)
        }
    }
    
    /// Specify the next chained action for the promise and return
    /// a new promise
    ///
    /// Error is chained with the new promise if no error handler
    /// is set for the current one
    func then<NextResultType>(_ nextFunction: @escaping (ResultType) throws -> NextResultType?) -> NineAnimatorPromise<NextResultType> {
        let promise = NineAnimatorPromise<NextResultType>(queue: self.queue, nil)
        promise.chainedReference = self // Store our reference to the chained promise
        
        // Set resolve callback
        chainedPromiseCallback = {
            result in
            do {
                if let nextResult = try nextFunction(result) {
                    promise.resolve(nextResult)
                } else { promise.reject(NineAnimatorError.unknownError) }
            } catch { promise.reject(error) }
        }
        
        // Pass on the error if no handler is set
        if chainedErrorCallback == nil {
            chainedErrorCallback = { error in promise.reject(error) }
        }
        
        return promise
    }
    
    /// Pass the result of the promise into another function, which generates
    /// another promise to be chained on.
    func thenPromise<NextResultType>(_ nextPromise: @escaping (ResultType) throws -> NineAnimatorPromise<NextResultType>?) -> NineAnimatorPromise<NextResultType> {
        let untilThenPromise = NineAnimatorPromise<NextResultType>(queue: self.queue, nil)
        untilThenPromise.chainedReference = self
        
        chainedPromiseCallback = {
            result in
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
            chainedErrorCallback = { error in untilThenPromise.reject(error) }
        }
        
        return untilThenPromise
    }
    
    /// Concludes the promise
    ///
    /// Promise is not executed until finally is called
    func finally(_ finalFunction: @escaping (ResultType) -> Void) -> NineAnimatorAsyncTask {
        if chainedErrorCallback == nil {
            Log.error("Promise concluded without error handler")
        }
        
        // Save callback and conclude the promise
        chainedPromiseCallback = finalFunction
        concludePromise()
        
        return self
    }
    
    /// Catches errors
    func error(_ handler: @escaping (Error) -> Void) -> NineAnimatorPromise {
        chainedErrorCallback = handler
        return self
    }
    
    /// Cancel the underlying NineAnimatorAsyncTask
    ///
    /// This method is thread safe
    func cancel() {
        // Atomicy
        semaphore.wait()
        defer { semaphore.signal() }
        
        referenceTask?.cancel()
        releaseAll()
    }
    
    /// Release references to all holding objects
    private func releaseAll() {
        referenceTask = nil
        chainedPromiseCallback = nil
        chainedErrorCallback = nil
        chainedReference = nil
        isResolved = true
    }
    
    /// Conclude the setup of promise and start the task
    fileprivate func concludePromise() {
        // Tell the previous promise to conclude first
        if let previous = chainedReference {
            previous.concludePromise()
        }
        
        // Run the initial task
        if let task = task {
            queue.async {
                [weak self] in
                guard let self = self else {
                    Log.error("Reference to promise lost before the initial task can run")
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
    static func firstly(queue: DispatchQueue = .global(), _ executingFunction: @escaping () throws -> ResultType?) -> NineAnimatorPromise {
        return NineAnimatorPromise(queue: queue) {
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
            Log.error("Losing reference to unresolved promise")
        }
        cancel()
    }
}
