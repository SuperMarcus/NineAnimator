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

public extension TimeInterval {
    /// A brief description of the duration
    var durationDescription: String {
        let intervalLabel: String
        
        switch self {
        case ..<60: intervalLabel = "within a minute"
        case 60..<(60 * 60): intervalLabel = "\(Int(self / 60)) minutes ago"
        case (60 * 60)..<(60 * 60 * 24): intervalLabel = "\(Int(self / (60 * 60))) hours ago"
        default: intervalLabel = "\(Int(self / (60 * 60 * 24))) days ago"
        }
        
        return intervalLabel
    }
}
