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

extension Array: ExpressibleByDictionaryLiteral where Element == URLQueryItem {
    public typealias Key = String
    
    public typealias Value = CustomStringConvertible
    
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(elements.map {
            URLQueryItem(name: $0.0, value: $0.1.description)
        })
    }
}
