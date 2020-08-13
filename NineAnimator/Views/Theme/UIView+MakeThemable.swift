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

import UIKit

@IBDesignable
extension UIView {
    @IBInspectable
    var isThemable: Bool {
        get { false }
        set {
            if newValue { makeThemable() }
        }
    }
    
    var themableOptionsStore: [String: Any] {
        get { layer.style?["themable.options"] as? [String: Any] ?? [:] }
        set {
            var layerStyles = layer.style ?? [:]
            layerStyles["themable.options"] = newValue
            layer.style = layerStyles
        }
    }
    
    var disableTheming: Bool {
        get { layer.style?["themable.disabled"] as? Bool == true }
        set {
            var layerStyles = layer.style ?? [:]
            layerStyles["themable.disabled"] = newValue
            layer.style = layerStyles
        }
    }
    
    func makeThemable() {
        if let themableSelf = self as? Themable {
            Theme.provision(themableSelf)
        } else { Theme.provision(view: self) }
    }
}
