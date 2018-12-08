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
    var indicatorColor: UIColor = UIColor.blue
    
    @IBInspectable
    var nullColor: UIColor = UIColor.gray.withAlphaComponent(0.3)
    
    @IBInspectable
    var percentage: CGFloat = 0.0
    
    @IBInspectable
    var strokeWidth: CGFloat = 2.0
    
    @IBInspectable
    var indicatorRadius: CGFloat = 16.0
    
    @IBInspectable
    var playIconToRadiusRatio: CGFloat = 0.55
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
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
        
        centerPlayIcon.move(to: .init(
            x: centerPoint.x + (playIconRadius * cos(0 * .pi)),
            y: centerPoint.y + (playIconRadius * sin(0 * .pi))
            ))
        centerPlayIcon.addLine(to: .init(
            x: centerPoint.x + (playIconRadius * cos(2.0 / 3.0 * .pi)),
            y: centerPoint.y + (playIconRadius * sin(2.0 / 3.0 * .pi))
            ))
        centerPlayIcon.addLine(to: .init(
            x: centerPoint.x + (playIconRadius * cos(4.0 / 3.0 * .pi)),
            y: centerPoint.y + (playIconRadius * sin(4.0 / 3.0 * .pi))
            ))
        centerPlayIcon.addLine(to: .init(
            x: centerPoint.x + (playIconRadius * cos(2 * .pi)),
            y: centerPoint.y + (playIconRadius * sin(2 * .pi))
            ))
        centerPlayIcon.close()
        
        indicatorColor.setFill()
        centerPlayIcon.fill()
    }
}

class EpisodeTableViewCell: UITableViewCell {
    var episodeLink: Anime.EpisodeLink? = nil {
        didSet {
            titleLabel.text = episodeLink?.name
        }
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var progressIndicator: EpisodeAccessoryProcessIndicator!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
