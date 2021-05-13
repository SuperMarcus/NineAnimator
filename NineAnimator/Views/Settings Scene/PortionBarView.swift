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

@IBDesignable class PortionBarView: UIView {
    typealias Segment = (amount: Double, color: UIColor)
    
    var segments: [Segment]? = [
        (0.2, .systemOrange),
        (0.15, .systemBlue),
        (0.1, .systemGray),
        (0.08, .systemGreen)
    ]
    @IBInspectable var segmentSeparatorWidth: CGFloat = 0.5
    @IBInspectable var remainingSpaceColor: UIColor = UIColor.gray.withAlphaComponent(0.1)
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        contentMode = .redraw
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override func draw(_ rect: CGRect) {
        if let segments = segments {
            renderSegments(segments, in: rect)
        }
    }
    
    private func renderSegments(_ segments: [Segment], in rect: CGRect) {
        let totalWidth = bounds.width
        let height = bounds.height
        let segmentWidths = segments.map {
            totalWidth * CGFloat($0.amount)
        }
        let validSegments = zip(segments, segmentWidths).filter {
            $1 > segmentSeparatorWidth
        } .map { (width: $1, color: $0.color) }
        
        // Draw each segments
        var currentX: CGFloat = 0
        for (width, color) in validSegments {
            let path = UIBezierPath(rect: .init(
                x: currentX,
                y: 0,
                width: width - segmentSeparatorWidth,
                height: height
            ))
            color.setFill()
            path.fill()
            currentX += width
        }
        
        // Fill the reamaining space of the bar
        let remainingSpace = totalWidth - currentX
        if remainingSpace > 0 {
            let path = UIBezierPath(rect: .init(
                x: currentX,
                y: 0,
                width: remainingSpace,
                height: height
            ))
            remainingSpaceColor.setFill()
            path.fill()
        }
    }
}
