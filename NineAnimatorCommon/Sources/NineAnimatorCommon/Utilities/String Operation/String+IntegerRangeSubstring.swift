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

public extension String {
    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }
    
    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }
    
    subscript (bounds: NSRange) -> String {
        let range = Range(bounds, in: self)!
        return String(self[range])
    }
    
    subscript (_ matchResult: NSTextCheckingResult, at group: Int) -> String {
        let range = matchResult.range(at: group)
        if range.lowerBound == NSNotFound && range.length == 0 {
            return ""
        }
        return self[range]
    }
    
    subscript (range: PartialRangeFrom<Int>) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: range.lowerBound)
        return String(self[startIndex..<endIndex])
    }
    
    var matchingRange: NSRange {
        NSRange(location: 0, length: utf16.count)
    }
}
