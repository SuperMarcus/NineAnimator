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
class NACoreEngine: NSObject {
    /// Shared virtual machine instance, allowing values to be passed between contexts
    static let sharedVirtualMachine: JSVirtualMachine = sharedQueue.sync { JSVirtualMachine() }
    static let sharedQueue = DispatchQueue(label: "com.nineanimator.NACoreEngine")
    
    /// Instances of the core engines, used for lookups.
    @AtomicProperty
    private static var _coreEngineInstances = [ObjectIdentifier: WeakRef<NACoreEngine>]()
    
    let jsContext: JSContext
    let requestManager: NARequestManager
    
    private var _retainedPromises: [ObjectIdentifier: NineAnimatorAsyncTask]
    private lazy var _jsExports = NACoreEngineExportsNineAnimator(parent: self)
    private lazy var _jsLogger = NACoreEngineExportsLogging(engine: self, logger: Log)
    
    /// Initialize the CoreEngine with a provided request manager
    /// - Important: The initializer should never be called from inside the NACoreEngine.sharedQueue, as it will cause a deadlock.
    init(name: String, requestManager: NARequestManager) {
        let vm = NACoreEngine.sharedVirtualMachine
        self.jsContext = JSContext(virtualMachine: vm)
        self.requestManager = requestManager
        self._retainedPromises = [:]
        
        super.init()
        
        // Naming the context, not that it matters
        self.jsContext.name = "NACoreEngine(\(name))"
        self.initializeGlobalValues()
        
        // Register this instance
        NACoreEngine.registerInstance(self)
    }
    
    deinit {
        // Unregister instance
        NACoreEngine.unregisterInstance(self)
    }
       
    private func initializeGlobalValues() {
        // Objects
        self.jsContext.setObject(self._jsExports, forKeyedSubscript: "NineAnimator" as NSString)
        self.jsContext.setObject(self._jsLogger, forKeyedSubscript: "Log" as NSString)
        
        // Types
        self.jsContext.setObject(NACoreEngineExportsAnimeLink.self, forKeyedSubscript: "AnimeLink" as NSString)
        self.jsContext.setObject(NACoreEngineExportsEpisodeLink.self, forKeyedSubscript: "EpisodeLink" as NSString)
        self.jsContext.setObject(NACoreEngineExportsAdditionalEpisodeLinkInformation.self, forKeyedSubscript: "AdditionalEpisodeLinkInformation" as NSString)
        self.jsContext.setObject(NACoreEngineExportsAnime.self, forKeyedSubscript: "Anime" as NSString)
        self.jsContext.setObject(NACoreEngineExportsEpisode.self, forKeyedSubscript: "Episode" as NSString)
        self.jsContext.setObject(NACoreEngineExportsPlaybackMedia.self, forKeyedSubscript: "PlaybackMedia" as NSString)
    }
}

// MARK: - Error Handling
@available(iOS 13, *)
extension NACoreEngine {
    /// Throw an error in the current execution context
    func raiseErrorInContext(_ error: NSError) {
        let convertedError = self.convertToJSError(error)
        self.jsContext.exception = convertedError
    }
}

// MARK: - Promise Conversions
@available(iOS 13, *)
extension NACoreEngine {
    /// Convert a JavaScript promise to native promise
    func toNativePromise(_ corePromise: JSValue) -> NineAnimatorPromise<JSValue> {
        .init {
            [weak self] callback in
            guard let self = self else {
                return nil
            }
            
            if corePromise.isInstance(of: self.promiseType) {
                // Init rejector and resolver
                let rejector: @convention(block) (JSValue) -> Void = {
                    [weak self] errorValue in
                    guard let self = self else {
                        return callback(nil, NineAnimatorError.unknownError("CoreEngine released"))
                    }
                    callback(nil, self.toNativeError(errorValue))
                }
                let resolver: @convention(block) (JSValue) -> Void = {
                    value in
                    callback(value, nil)
                }
                corePromise.invokeMethod("then", withArguments: [
                    self.convertToJSValue(resolver),
                    self.convertToJSValue(rejector)
                ])
            } else {
                Log.debug("[NACoreEngine] Cannot convert object %@ to native promise.", corePromise)
            }
            
            return nil
        }
    }
    
    /// Retain an instance of NineAnimatorPromise in the current context, return a JSValue containing a JavaScript promise.
    func retainNativePromise(_ promise: NineAnimatorPromise<JSValue>) -> JSValue {
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
}

// MARK: - Lookup Instances
@available(iOS 13, *)
extension NACoreEngine {
    private static func registerInstance(_ engine: NACoreEngine) {
        Log.info("[NACoreEngine] Registering NACoreEngine instance: %@", engine)
        __coreEngineInstances.mutate {
            $0[ObjectIdentifier(engine.jsContext)] = WeakRef(engine)
        }
    }
    
    private static func unregisterInstance(_ engine: NACoreEngine) {
        Log.info("[NACoreEngine] Unregistering NACoreEngine instance: %@", engine)
        __coreEngineInstances.mutate {
            _ = $0.removeValue(forKey: ObjectIdentifier(engine.jsContext))
        }
    }
    
    /// Retrieve the NACoreEngine instance from a JavaScript execution context
    static func current() -> NACoreEngine? {
        if let currentContext = JSContext.current() {
            return instance(forContext: currentContext)
        } else {
            Log.error("[NACoreEngine] Calling NACoreEngine.current() outside a JavaScript execution context results in undefined behaviors!!")
            return nil
        }
    }
    
    /// Obtain a registered instance of NACoreEngine for the given JSContext
    static func instance(forContext context: JSContext) -> NACoreEngine? {
        $_coreEngineInstances.synchronize {
            $0[ObjectIdentifier(context)]?.object
        }
    }
}
