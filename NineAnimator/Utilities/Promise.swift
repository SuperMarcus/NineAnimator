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

/// NineAnimator's implementation of promise
///
/// Since NineAnimator is involved in many chainned networking stuff,
/// which, as many can tell, creates numerous "callback hells" in the
/// code, and that Marcus couldn't come up with which promise
/// framework to use, I am just going to write one myself.
class NineAnimatorPromise<ResultType>: NineAnimatorAsyncTask {
    // Hold reference to the task
    private var referenceTask: NineAnimatorAsyncTask?
    
    // A promise can only be resolved once. This is a flag
    // to make sure of that.
    private(set) var isResolved = false
    
    private var chainedPromiseCallback: ((ResultType) -> Void)?
    
    private var chainedErrorCallback: ((Error) -> Void)?
    
    // The DispatchQueue in which the task and the subsequent
    // promises will run in
    private var queue: DispatchQueue
    
    // A DispatchSemaphore for waiting the success resolver to be set
    private var successSemaphore: DispatchSemaphore
    
    // A DispatchSemaphore for waiting the error resolver to be set
    private var errorSemaphore: DispatchSemaphore
    
    // The latest DispatchTime that the resolvers can be set
    private var creationDate: DispatchTime = .now()
    
    typealias NineAnimatorPromiseCallback = NineAnimatorCallback<ResultType>
    
    /// Create a new promise in the DispatchQueue with a
    /// classic NineAnimator callback task
    init(queue: DispatchQueue = .global(), _ task: ((@escaping NineAnimatorPromiseCallback) -> NineAnimatorAsyncTask?)?) {
        // Execute the promise task in the DispatchQueue if there is one
        self.queue = queue
        self.successSemaphore = DispatchSemaphore(value: 0)
        self.errorSemaphore = DispatchSemaphore(value: 0)
        
        // Only continue to execute when the task is not nil
        guard let task = task else { return }
        
        queue.async {
            [weak self] in
            guard let self = self else {
                Log.error("Reference to promise is lost before the promised task can run")
                return
            }
            
            // Store the reference to the async task
            self.referenceTask = task {
                [weak self] result, error in
                if let result = result {
                    self?.resolve(result)
                } else { self?.reject(error ?? NineAnimatorError.providerError("Unknown Error")) }
            }
        }
    }
    
    /// Resolve the promise with value
    func resolve(_ value: ResultType) {
        defer { releaseAll() }
        
        guard !isResolved else {
            Log.error("Attempting to resolve a promise twice.")
            return
        }
        
        defer { isResolved = true }
        
        // Wait for at most 1 second after creation
        _ = successSemaphore.wait(timeout: creationDate + 1_000_000_000)
        if let resolver = chainedPromiseCallback {
            resolver(value)
        } else { Log.error("Promise has no resolver") }
    }
    
    /// Reject the promise with error
    func reject(_ error: Error) {
        defer { releaseAll() }
        
        guard !isResolved else {
            Log.error("Attempting to resolve a promise twice.")
            return
        }
        
        defer { isResolved = true }
        
        // Wait for at most 1 second after creation
        _ = errorSemaphore.wait(timeout: creationDate + 1_000_000_000)
        if let handler = chainedErrorCallback {
            handler(error)
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
        
        // Set resolve callback
        chainedPromiseCallback = {
            result in
            do {
                if let nextResult = try nextFunction(result) {
                    promise.resolve(nextResult)
                } else { promise.reject(NineAnimatorError.unknownError) }
            } catch { promise.reject(error) }
        }
        successSemaphore.signal()
        
        // Pass on the error if none
        if chainedErrorCallback == nil {
            chainedErrorCallback = { error in promise.reject(error) }
            errorSemaphore.signal()
        }
        
        return promise
    }
    
    /// Concludes the promise
    func finally(_ finalFunction: @escaping (ResultType) -> Void) -> NineAnimatorAsyncTask {
        chainedPromiseCallback = finalFunction
        successSemaphore.signal()
        return self
    }
    
    /// Catches errors
    func error(_ handler: @escaping (Error) -> Void) -> NineAnimatorPromise {
        chainedErrorCallback = handler
        errorSemaphore.signal()
        return self
    }
    
    /// Cancel the underlying NineAnimatorAsyncTask
    func cancel() {
        referenceTask?.cancel()
        releaseAll()
    }
    
    /// Release references to all holding objects
    private func releaseAll() {
        referenceTask = nil
        chainedPromiseCallback = nil
        chainedErrorCallback = nil
        successSemaphore.signal()
        errorSemaphore.signal()
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
    
    deinit { cancel() }
}
