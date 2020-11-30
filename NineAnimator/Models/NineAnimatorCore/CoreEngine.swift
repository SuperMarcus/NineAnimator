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
import JavaScriptCore

@available(iOS 13, *)
class NACoreEngine {
    /// Shared virtual machine instance, allowing values to be passed between contexts
    static let sharedVirtualMachine: JSVirtualMachine = sharedQueue.sync { JSVirtualMachine() }
    static let sharedQueue = DispatchQueue(label: "com.nineanimator.NACoreEngine")
    
    let jsContext: JSContext
    let requestManager: NARequestManager
    
    private var _retainedPromises: [ObjectIdentifier: NineAnimatorAsyncTask]
    private lazy var _jsExports = NineAnimatorNamespaceExports(parent: self)
    
    /// Initialize the CoreEngine with a provided reuqest manager
    /// - Important: The initializer should never be called from inside the NACoreEngine.sharedQueue, as it will cause a deadlock.
    init(requestManager: NARequestManager) {
        let vm = NACoreEngine.sharedVirtualMachine
        self.jsContext = JSContext(virtualMachine: vm)
        self.requestManager = requestManager
        self._retainedPromises = [:]
        
        // Naming the context, not that it matters
        self.jsContext.name = "NACoreEngine"
    }
    
    /// Retain an instance of NineAnimatorPromise in the current context, return a JSValue containing a JavaScript promise.
    func retrainNativePromise(_ promise: NineAnimatorPromise<JSValue>) -> JSValue {
        let jsPromise = JSValue(newPromiseIn: self.jsContext) {
            [weak self] resolver, rejector in
            guard let resolver = resolver, let rejector = rejector else {
                return
            }
            
            NACoreEngine.sharedQueue.async {
                guard let strongSelf = self else {
                    return
                }
                
                let task = promise.defer {
                    task in
                    guard let self = self else {
                        return
                    }
                    
                    // Remove reference to this promise
                    self._retainedPromises.removeValue(forKey: ObjectIdentifier(task))
                } .error {
                    error in
                    guard let self = self else {
                        return
                    }
                    
                    let convertedError = self.convertToJSError(error as NSError)
                    rejector.call(withArguments: [ convertedError ])
                } .finally {
                    result in
                    guard case .some = self else {
                        return
                    }
                    
                    // Call resolver
                    resolver.call(withArguments: [ result ])
                }
                
                // Retain the promise within the engine
                strongSelf._retainedPromises[ObjectIdentifier(task)] = task
            }
        }
        
        return jsPromise ?? JSValue(undefinedIn: self.jsContext)
    }
    
    func convertToJSError(_ nativeError: NSError) -> JSValue {
        JSValue(object: nativeError, in: jsContext)
    }
    
    private func initializeGlobalValues() {
        self.jsContext.setObject(self._coreEngineFetch, forKeyedSubscript: "fetch" as NSString)
        self.jsContext.setObject(self._jsExports, forKeyedSubscript: "NineAnimator" as NSString)
    }
}
