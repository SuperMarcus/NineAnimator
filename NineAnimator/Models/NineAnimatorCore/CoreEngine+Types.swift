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
        if let coreError = nativeError as? NineAnimatorError.CoreEngineError,
           let instantiatedError = coreError.errorObject?.value {
            return instantiatedError
        }
        
        let formattedErrorMessage = String(format: "%@: %@", nativeError.localizedDescription, nativeError.localizedFailureReason ?? "unknown reason")
        
        guard let errorObject = JSValue(newErrorFromMessage: formattedErrorMessage, in: jsContext) else {
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
            return NineAnimatorError.CoreEngineError(errorObject: jsErrorValue, name: errorName, message: errorMessage)
        } else {
            let convertedErrorMessage = jsErrorValue.toString()
            return NineAnimatorError.unknownError(convertedErrorMessage ?? "Unknown JavaScript Error")
        }
    }
    
    /// Convert a JavaScript value to a native object
    func toNativeObject<ObjectType>(_ jsValue: JSValue, type: ObjectType.Type) -> ObjectType? {
        if let jsValueObject = jsValue.toObject(),
           let convertedObject = jsValueObject as? ObjectType {
            return convertedObject
        }
        return nil
    }
    
    /// Validate the type of an input value
    func validateValue<InputType, ParameterType>(_ inputValue: InputType?, type: ParameterType.Type) -> ParameterType? {
        // I want my sweet type safety
        if let coreObject = (inputValue as? JSValue) ?? JSValue(object: inputValue, in: self.jsContext) {
            return self.toNativeObject(coreObject, type: type)
        }
        
        return nil
    }
    
    /// Validate the type of an input value
    ///
    /// Always use this method to check callback parameters that involve generic bridged classes (such as NSArray and NSDictionary)
    /// since JavaScriptCore does not provide type-safety checks in such instances.
    func validateValue<InputType>(_ inputValue: InputType?) -> InputType? {
        // I also want my type safety :)
        validateValue(inputValue, type: InputType.self)
    }
}
