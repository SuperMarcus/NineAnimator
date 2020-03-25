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

class SharedPointerEffectDelegate: NSObject {
    static let shared: SharedPointerEffectDelegate = .init()
    
    override private init() {
        super.init()
    }
}

extension SharedPointerEffectDelegate {
    enum Effect: Int {
        case `default` = 0
        case highlight
        case hover
        case lift
    }
}

@available(iOS 13.4, *)
extension SharedPointerEffectDelegate: UIPointerInteractionDelegate {
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        var style: UIPointerStyle?
        
        if let view = interaction.view, let effect = view.pointerEffect.currentEffect {
            let preview = UITargetedPreview(view: view)
            let pointerEffect: UIPointerEffect
            
            switch effect {
            case .default: pointerEffect = .automatic(preview)
            case .highlight: pointerEffect = .highlight(preview)
            case .hover: pointerEffect = .hover(
                    preview,
                    preferredTintMode: .overlay,
                    prefersShadow: view.pointerEffect.hoverEffectUseShadow,
                    prefersScaledContent: view.pointerEffect.hoverEffectUseScale
                )
            case .lift: pointerEffect = .lift(preview)
            }
            
            style = UIPointerStyle(effect: pointerEffect)
        }
        
        return style
    }
}
