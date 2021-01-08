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
class EpisodeAccessoryProcessIndicator: UIView, Themable {
    @IBInspectable
    lazy var indicatorColor: UIColor = tintColor
    
    @IBInspectable
    var nullColor: UIColor = UIColor.lightGray.withAlphaComponent(0.4)
    
    @IBInspectable
    var strokeWidth: CGFloat = 2.0
    
    @IBInspectable
    var indicatorRadius: CGFloat = 16.0
    
    @IBInspectable
    var playIconToRadiusRatio: CGFloat = 0.55
    
    var episodeLink: EpisodeLink? {
        didSet {
            setNeedsDisplay()
            
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onProgressUpdate),
                name: .playbackProgressDidUpdate,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onProgressUpdate),
                name: .batchPlaybackProgressDidUpdate,
                object: nil
            )
        }
    }
    
    @objc func onProgressUpdate() {
        DispatchQueue.main.async { self.setNeedsDisplay() }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        var percentage = 0 as CGFloat
        
        if let episodeLink = episodeLink {
            percentage = CGFloat(episodeLink.playbackProgress)
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
    
    func theme(didUpdate theme: Theme) {
        indicatorColor = theme.tint
        nullColor = theme.secondaryText.withAlphaComponent(0.4)
        setNeedsDisplay()
    }
}
