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

public extension NSRegularExpression {
    func matches(in content: String, options: NSRegularExpression.MatchingOptions = []) -> [NSTextCheckingResult] {
        matches(in: content, options: options, range: content.matchingRange)
    }
    
    // Return the groups of the first match
    func firstMatch(in content: String, options: NSRegularExpression.MatchingOptions = []) -> [String]? {
        guard let match = matches(in: content, options: options).first else { return nil }
        return (0..<match.numberOfRanges).map { content[match, at: $0] }
    }
    
    // Return the groups of the last match
    func lastMatch(in content: String, options: NSRegularExpression.MatchingOptions = []) -> [String]? {
        guard let match = matches(in: content, options: options).last else { return nil }
        return (0..<match.numberOfRanges).map { content[match, at: $0] }
    }
}
