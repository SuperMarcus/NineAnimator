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

public func encodeIfPresent<T: Encodable>(data: T?) -> Data? {
    let encoder = PropertyListEncoder()
    return try? encoder.encode(data)
}

public func decodeIfPresent<T: Decodable>(_ type: T.Type, from data: Any?) -> T? {
    guard let data = data as? Data else { return nil }
    let decoder = PropertyListDecoder()
    return try? decoder.decode(type, from: data)
}

public func encode<T: Encodable>(data: T) throws -> Data {
    let encoder = PropertyListEncoder()
    return try encoder.encode(data)
}

public func decode<T: Decodable>(_ type: T.Type, from data: Any?) throws -> T {
    guard let data = data as? Data else {
        throw NineAnimatorError.decodeError
    }
    let decoder = PropertyListDecoder()
    return try decoder.decode(type, from: data)
}
