//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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

import UIKit

@IBDesignable
extension UITableViewCell {
    /// Use Theme.tint for the color of the text
    @IBInspectable var tintText: Bool {
        get { themableOptionsStore["cell.tintText"] as? Bool ?? false }
        set { themableOptionsStore["cell.tintText"] = newValue }
    }
    
    /// Mark the color of the labels in this cell as predetermined
    /// - Note: This prevents `Theme` from updating the foreground colors of the labels in the cell.
    @IBInspectable var determinedLabelColors: Bool {
        get { themableOptionsStore["cell.determinedLabelColors"] as? Bool ?? false }
        set { themableOptionsStore["cell.determinedLabelColors"] = newValue }
    }
}
