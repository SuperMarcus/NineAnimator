//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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

//https://stackoverflow.com/questions/805872/how-do-i-draw-a-shadow-under-a-uiview
@IBDesignable extension UIView {
    @IBInspectable var cornerRadius: Float {
        set { layer.cornerRadius = CGFloat(newValue) }
        get { return Float(layer.cornerRadius) }
    }
    
    /* The color of the shadow. Defaults to opaque black. Colors created
     * from patterns are currently NOT supported. Animatable. */
    @IBInspectable var shadowColor: UIColor? {
        set { layer.shadowColor = newValue!.cgColor }
        get {
            if let color = layer.shadowColor {
                return UIColor(cgColor: color)
            } else { return nil }
        }
    }
    
    /* The opacity of the shadow. Defaults to 0. Specifying a value outside the
     * [0,1] range will give undefined results. Animatable. */
    @IBInspectable var shadowOpacity: Float {
        set { layer.shadowOpacity = newValue }
        get { return layer.shadowOpacity }
    }
    
    /* The shadow offset. Defaults to (0, -3). Animatable. */
    @IBInspectable var shadowOffset: CGPoint {
        set { layer.shadowOffset = CGSize(width: newValue.x, height: newValue.y) }
        get { return CGPoint(x: layer.shadowOffset.width, y: layer.shadowOffset.height) }
    }
    
    /* The blur radius used to create the shadow. Defaults to 3. Animatable. */
    @IBInspectable var shadowRadius: CGFloat {
        set { layer.shadowRadius = newValue }
        get { return layer.shadowRadius }
    }
    
    @IBInspectable var ignoresInvertColors: Bool {
        set { accessibilityIgnoresInvertColors = newValue }
        get { return accessibilityIgnoresInvertColors }
    }
}
