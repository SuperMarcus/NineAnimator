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
class ThemedSolidButton: UIButton, Themable {
    @IBInspectable var inverted: Bool = false
    
    override var isHighlighted: Bool {
        get { super.isHighlighted }
        set {
            super.isHighlighted = newValue
            if newValue {
                backgroundColor = backgroundColor?.withAlphaComponent(0.6)
                imageView?.alpha = 0.6
            } else {
                backgroundColor = backgroundColor?.withAlphaComponent(1.0)
                imageView?.alpha = 1.0
            }
        }
    }
    
    func theme(didUpdate theme: Theme) {
        if inverted {
            backgroundColor = theme.tint
            tintColor = theme.secondaryBackground
            imageView?.tintColor = theme.secondaryBackground
            setTitleColor(theme.secondaryBackground, for: .normal)
            setTitleColor(theme.secondaryBackground.withAlphaComponent(0.6), for: .highlighted)
        } else {
            backgroundColor = theme.secondaryBackground
            tintColor = theme.primaryText
            imageView?.tintColor = theme.primaryText
            setTitleColor(theme.primaryText, for: .normal)
            setTitleColor(theme.primaryText.withAlphaComponent(0.6), for: .highlighted)
        }
    }
}
