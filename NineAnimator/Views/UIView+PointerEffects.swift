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

import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources
import UIKit

/// Helper class to configure custom pointer effects
class PointerEffectConfigurator {
    /// Reference to the parent view
    let parent: UIView
    
    /// Retrieve or access the set pointer effect of this view
    var currentEffect: SharedPointerEffectDelegate.Effect? {
        get { parent.themableOptionsStore["pointerEffect"] as? SharedPointerEffectDelegate.Effect }
        set { parent.themableOptionsStore["pointerEffect"] = newValue }
    }
    
    /// For hover effect only. Prefer shadows.
    var hoverEffectUseShadow: Bool {
        get { parent.themableOptionsStore["pointerEffect.shadow"] as? Bool ?? false }
        set { parent.themableOptionsStore["pointerEffect.shadow"] = newValue }
    }
    
    /// For hover effect only. Use scales.
    var hoverEffectUseScale: Bool {
        get { parent.themableOptionsStore["pointerEffect.scale"] as? Bool ?? false }
        set { parent.themableOptionsStore["pointerEffect.scale"] = newValue }
    }
    
    fileprivate init(parent: UIView) {
        self.parent = parent
    }
    
    /// Use the highlight effect
    func highlight() {
        currentEffect = .highlight
        registerInteraction()
    }
    
    /// Use the hover effect
    func hover(shadow: Bool = false, scale: Bool = false) {
        currentEffect = .hover
        hoverEffectUseShadow = shadow
        hoverEffectUseScale = scale
        registerInteraction()
    }
    
    /// Use the lift effect
    func lift() {
        currentEffect = .lift
        registerInteraction()
    }
    
    /// Add the `UIPointerInteraction` to the parent view
    private func registerInteraction() {
        if #available(iOS 13.4, *) {
            if let interaction = parent.interactions.first(where: {
                ($0 as? UIPointerInteraction)?.delegate is SharedPointerEffectDelegate
            }) as? UIPointerInteraction {
                // Make sure the interaction is enabled
                interaction.isEnabled = true
            } else {
                // Add interaction if the pointer interaction hasn't been added
                let interaction  = UIPointerInteraction(delegate: SharedPointerEffectDelegate.shared)
                parent.addInteraction(interaction)
            }
        }
    }
}

extension UIView {
    /// Retrieve the pointer effect configurator struct
    var pointerEffect: PointerEffectConfigurator {
        PointerEffectConfigurator(parent: self)
    }
}
