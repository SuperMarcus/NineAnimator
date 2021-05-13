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
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources

@available(iOS 13, *)
@objc protocol NACoreEngineExportsLoggingProtocol: JSExport {
    func info(_ message: String)
    func debug(_ message: String)
    func error(_ errorObject: JSValue)
}

@available(iOS 13, *)
@objc class NACoreEngineExportsLogging: NSObject, NACoreEngineExportsLoggingProtocol {
    private var logger: NineAnimatorLogger
    private var managedConsoleObject: JSManagedValue?
    private unowned let engine: NACoreEngine
    
    init(engine: NACoreEngine, logger: NineAnimatorLogger) {
        self.engine = engine
        self.logger = logger
        
        super.init()
        
        if let jsConsoleObject = engine.jsContext.objectForKeyedSubscript("console" as NSString),
           jsConsoleObject.isObject {
            self.managedConsoleObject = .init(value: jsConsoleObject, andOwner: self)
        }
    }
    
    func info(_ message: String) {
        self.logger.info("[NACore.Info] %@", message)
        self.managedConsoleObject?.value?.invokeMethod("info", withArguments: [ message ])
    }
    
    func debug(_ message: String) {
        self.logger.debug("[NACore.Debug] %@", message)
        self.managedConsoleObject?.value?.invokeMethod("debug", withArguments: [ message ])
    }
    
    func error(_ errorObject: JSValue) {
        if errorObject.isInstance(of: self.engine.errorType) {
            let nativeError = self.engine.toNativeError(errorObject)
            self.logger.error("[NACore.Error] %@", nativeError)
        } else {
            self.logger.error("[NACore.Error] %@", errorObject.toString() ?? "Unknown Error")
        }
        
        self.managedConsoleObject?.value?.invokeMethod("error", withArguments: [ errorObject ])
    }
}
