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

public extension UserDefaults {
    /// The method used to encode the value
    enum CodableEncodingMethod {
        /// Use `DictionaryEncoder` and encode the value into the defaults store as a dictionary
        case dictionary
        
        /// Use `PropertyListEncoder` and encode the value into the defaults store as a data
        case propertyList
        
        /// Use `JSONEncoder` and encode the value into the defaults store as a json string
        case json
    }
    
    /// Encode a value of type `T` into the defaults store
    func setCodable<T: Encodable>(_ value: T,
                                  encoding: CodableEncodingMethod = .dictionary,
                                  forKey key: String) throws {
        let encodedValue: Any
        switch encoding {
        case .dictionary:
            encodedValue = try DictionaryEncoder().encode(value) as NSDictionary
        case .propertyList:
            encodedValue = try PropertyListEncoder().encode(value)
        case .json:
            let encodedJsonData = try JSONEncoder().encode(value)
            encodedValue = try String(
                data: encodedJsonData,
                encoding: .utf8
            ).tryUnwrap()
        }
        self.set(encodedValue, forKey: key)
    }
    
    /// Retrieve a value of type `T` encoded to the defaults by the `setCodable()` method
    func codable<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T {
        if let encodedDictionaryStore = self.dictionary(forKey: key) {
            return try DictionaryDecoder().decode(T.self, from: encodedDictionaryStore)
        }
        
        if let encodedStringStore = self.string(forKey: key) {
            let encodedJsonData = try encodedStringStore
                .data(using: .utf8)
                .tryUnwrap(.decodeError)
            return try JSONDecoder().decode(T.self, from: encodedJsonData)
        }
        
        if let encodedDataStore = self.data(forKey: key) {
            return try PropertyListDecoder().decode(T.self, from: encodedDataStore)
        }
        
        throw NineAnimatorError.decodeError("Unable to decode value with key '\(key)': value doesn't exists or is using an unsupported coding type.")
    }
}
