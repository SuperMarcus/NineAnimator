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

public func formEncode(_ dict: [String: CustomStringConvertible]) throws -> String {
    var encoder = URLComponents()
    encoder.queryItems = dict.map { .init(name: $0.key, value: $0.value.description) }
    return try some(encoder.percentEncodedQuery, or: .urlError)
}

public func formDecode(_ form: String) throws -> [String: String] {
    var decoder = URLComponents()
    decoder.percentEncodedQuery = form
    let items = try some(decoder.queryItems, or: .urlError)
    return Dictionary(uniqueKeysWithValues: try items.map { ($0.name, try some($0.value, or: .urlError)) })
}
