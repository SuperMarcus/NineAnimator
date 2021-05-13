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

public extension Dictionary {
    /// Obtain value with the provided keypath
    func value(at path: String) -> Any? {
        (self as NSDictionary).value(forKeyPath: path)
    }
    
    /// Obtain value at path of a specific type
    func value<T>(at path: String, type: T.Type) throws -> T {
        guard let v = value(at: path) as? T else {
            throw NineAnimatorError.decodeError
        }
        return v
    }
    
    /// Obtain the value at key with a typed default value T
    subscript<T>(_ key: Key, typedDefault defaultValue: T) -> T {
        (self[key] as? T) ?? defaultValue
    }
}

public extension NSDictionary {
    func value<T>(at path: String, type: T.Type) throws -> T {
        guard let v = value(forKeyPath: path) as? T else {
            throw NineAnimatorError.decodeError(path)
        }
        return v
    }
    
    func valueIfPresent<T>(at path: String, type: T.Type) -> T? {
        value(forKeyPath: path) as? T
    }
}
