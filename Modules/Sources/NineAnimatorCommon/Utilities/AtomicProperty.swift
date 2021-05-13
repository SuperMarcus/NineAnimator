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

/// An atomic property wrapper that protects the values from concurrent access and mutations
@propertyWrapper
public class AtomicProperty<Value> {
    private var _value: Value
    private let _lock: NSLock
    
    /// Obtain the value contained by this wrapper
    public var wrappedValue: Value {
        _lock.lock { _value }
    }
    
    public var projectedValue: AtomicProperty<Value> {
        self
    }
    
    public init(wrappedValue value: Value) {
        self._value = value
        self._lock = NSLock()
    }
    
    /// Mutate the value contained in the wrapped
    /// - Important: Do not attempt to access the `AtomicProperty` container inside
    ///   the `mutationBlock` as it may cause a deadlock.
    @discardableResult
    public func mutate<Result>(_ mutationBlock: (inout Value) throws -> Result) rethrows -> Result {
        try _lock.lock {
            try mutationBlock(&_value)
        }
    }
    
    /// Perform an operation on the value granted that it will not change during the execution of the block
    /// - Important: Do not attempt to access the `AtomicProperty` container inside
    ///   the `mutationBlock` as it may cause a deadlock.
    public func synchronize<Result>(_ synchronizeBlock: (Value) throws -> Result) rethrows -> Result {
        try _lock.lock {
            try synchronizeBlock(_value)
        }
    }
}
