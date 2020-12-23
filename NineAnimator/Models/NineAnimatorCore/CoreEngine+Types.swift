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

/// Helper functions for type conversions
@available(iOS 13, *)
extension NACoreEngine {
    /// A JavaScript undefined value
    var undefinedValue: JSValue {
        .init(undefinedIn: jsContext)
    }
    
    /// A JavaScript null value
    var nullValue: JSValue {
        .init(nullIn: jsContext)
    }
    
    /// JavaScript Promise type
    var promiseType: JSValue {
        jsContext.objectForKeyedSubscript("Promise" as NSString) ?? self.undefinedValue
    }
    
    /// JavaScript Error type
    var errorType: JSValue {
        jsContext.objectForKeyedSubscript("Error" as NSString) ?? self.undefinedValue
    }
    
    /// Make a JavaScript error object from a native NSError object
    func convertToJSError(_ nativeError: NSError) -> JSValue {
        // Reuse instantiated JSCore error
        if let coreError = nativeError as? NineAnimatorError.NineAnimatorCoreError,
           let instantiatedError = coreError.errorObject?.value {
            return instantiatedError
        }
        
        guard let errorObject = JSValue(newErrorFromMessage: nativeError.localizedDescription, in: jsContext) else {
            return JSValue(undefinedIn: jsContext)
        }
        
        // Name of error
        errorObject.setObject("\(nativeError.domain) (\(nativeError.code))", forKeyedSubscript: "name" as NSString)
        
        // Additional information useful for debugging
        errorObject.setObject(nativeError, forKeyedSubscript: "nativeError" as NSString)
        errorObject.setObject(nativeError.description, forKeyedSubscript: "description" as NSString)
        errorObject.setObject(nativeError.localizedFailureReason, forKeyedSubscript: "localizedFailureReason" as NSString)
        errorObject.setObject(nativeError.localizedDescription, forKeyedSubscript: "localizedDescription" as NSString)
        errorObject.setObject(nativeError.localizedRecoveryOptions, forKeyedSubscript: "localizedRecoveryOptions" as NSString)
        errorObject.setObject(nativeError.localizedRecoverySuggestion, forKeyedSubscript: "localizedRecoverySuggestion" as NSString)
        errorObject.setObject(nativeError.userInfo, forKeyedSubscript: "userInfo")
        errorObject.setObject(Thread.callStackSymbols, forKeyedSubscript: "nativeCallStackSymbols" as NSString)
        errorObject.setObject(true, forKeyedSubscript: "isNativeError" as NSString)
        
        return errorObject
    }
    
    /// Wrap object in JSValue
    func convertToJSValue(_ value: Any) -> JSValue {
        .init(object: value, in: jsContext)
    }
    
    /// Convert a JavaScript error value to native error
    func toNativeError(_ jsErrorValue: JSValue) -> NSError {
        if let directNativeError = jsErrorValue as? NSError {
            return directNativeError
        } else if let nativeError = jsErrorValue.objectForKeyedSubscript("nativeError") as? NSError {
            return nativeError
        } else if jsErrorValue.isInstance(of: self.errorType) {
            let errorName = jsErrorValue.objectForKeyedSubscript("name")?.toString() ?? "UnknownError"
            let errorMessage = jsErrorValue.objectForKeyedSubscript("message")?.toString() ?? "Unknown message"
            return NineAnimatorError.NineAnimatorCoreError(errorObject: jsErrorValue, name: errorName, message: errorMessage)
        } else {
            let convertedErrorMessage = jsErrorValue.toString()
            return NineAnimatorError.unknownError(convertedErrorMessage ?? "Unknown JavaScript Error")
        }
    }
}
