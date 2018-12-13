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
class EpisodeAccessoryProcessIndicator: UIView {
    @IBInspectable
    lazy var indicatorColor: UIColor = tintColor
    
    @IBInspectable
    var nullColor: UIColor = .lightGray
    
    @IBInspectable
    var strokeWidth: CGFloat = 2.0
    
    @IBInspectable
    var indicatorRadius: CGFloat = 16.0
    
    @IBInspectable
    var playIconToRadiusRatio: CGFloat = 0.55
    
    var episodeLink: EpisodeLink? {
        didSet { setNeedsDisplay() }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        var percentage: CGFloat = 0
        
        if let episodeLink = episodeLink {
            percentage = CGFloat(NineAnimator.default.user.playbackProgress(for: episodeLink))
        }
        
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        
        let nullRing = UIBezierPath()
        
        nullRing.addArc(
            withCenter: centerPoint,
            radius: indicatorRadius + (strokeWidth / 2),
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true)
        
        nullRing.lineWidth = strokeWidth
        nullColor.setStroke()
        nullRing.stroke()
        
        let completedRing = UIBezierPath()
        
        completedRing.addArc(
            withCenter: centerPoint,
            radius: indicatorRadius + (strokeWidth / 2),
            startAngle: -0.5 * .pi,
            endAngle: (percentage * 2 * .pi) - (0.5 * .pi),
            clockwise: true)
        
        completedRing.lineWidth = strokeWidth
        indicatorColor.setStroke()
        completedRing.stroke()
        
        let centerPlayIcon = UIBezierPath()
        let playIconRadius = indicatorRadius * playIconToRadiusRatio
        
        centerPlayIcon.move(to: CGPoint(
            x: centerPoint.x + playIconRadius,
            y: centerPoint.y
        ))
        
        for theta in [2.0 / 3.0, 4.0 / 3.0, 2] {
            centerPlayIcon.addLine(to: CGPoint(
                x: centerPoint.x + playIconRadius * CGFloat(__cospi(theta)),
                y: centerPoint.y + playIconRadius * CGFloat(__sinpi(theta))
            ))
        }
        
        centerPlayIcon.close()
        
        indicatorColor.setFill()
        centerPlayIcon.fill()
    }
}
