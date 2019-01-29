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

@IBDesignable
class OfflineAccessButton: UIButton, Themable {
    enum OfflineState {
        case ready
        case preserved
        case preserving(Float)
    }
    
    var offlineAccessState: OfflineState = .preserving(0.5) {
        didSet { updateContent() }
    }
    
    @IBInspectable var insetSpace: CGFloat = 8 {
        didSet { updateContent() }
    }
    
    @IBInspectable var imageSize: CGSize = .init(width: 40, height: 40) {
        didSet { updateContent() }
    }
    
    @IBInspectable var strokeWidth: CGFloat = 2 {
        didSet { updateContent() }
    }
    
    @IBInspectable var centerRectWidth: CGFloat = 8 {
        didSet { updateContent() }
    }
    
    @IBInspectable var centerRectCornerRadius: CGFloat = 2 {
        didSet { updateContent() }
    }
    
    private func updateContent() {
        switch offlineAccessState {
        case .ready: setImage(#imageLiteral(resourceName: "Cloud Download"), for: .normal)
        case .preserved: setImage(UIImage(), for: .normal)
        case .preserving(let progress):
            let size = CGSize(width: 40, height: 40)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image {
                _ in
                
                let trackPath = UIBezierPath(
                    arcCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    radius: size.width / 2 - insetSpace,
                    startAngle: 0,
                    endAngle: 2 * .pi,
                    clockwise: true
                )
                trackPath.lineWidth = strokeWidth
                Theme.current.secondaryText.withAlphaComponent(0.4).setStroke()
                trackPath.stroke()
                
                let progressPath = UIBezierPath(
                    arcCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    radius: size.width / 2 - insetSpace,
                    startAngle: 3 * .pi / 2,
                    endAngle: (CGFloat(3) * .pi / 2) + (CGFloat(2) * .pi * CGFloat(progress)),
                    clockwise: true
                )
                progressPath.lineWidth = strokeWidth
                Theme.current.tint.setStroke()
                progressPath.stroke()
                
                let centerRect = UIBezierPath(
                    roundedRect: CGRect(
                        x: (size.width / 2) - (centerRectWidth / 2),
                        y: (size.height / 2) - (centerRectWidth / 2),
                        width: centerRectWidth,
                        height: centerRectWidth
                    ),
                    byRoundingCorners: .allCorners,
                    cornerRadii: CGSize(width: centerRectCornerRadius, height: centerRectCornerRadius)
                )
                Theme.current.tint.setFill()
                centerRect.fill()
            }
            setImage(image, for: .normal)
        }
    }
    
    func theme(didUpdate theme: Theme) { updateContent() }
}
