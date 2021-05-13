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

class ServerSelectionCell: UITableViewCell, Themable {
    @IBOutlet private weak var sourceLogoImageView: UIImageView!
    @IBOutlet private weak var sourceNameLabel: UILabel!
    @IBOutlet private weak var sourceDescriptionLabel: UILabel!
    @IBOutlet private weak var sourceStateLabel: UILabel!
    
    private(set) var representingSource: Source?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Default to non-selected state
        sourceStateLabel.alpha = 0
        clipsToBounds = true
    }
    
    func setPresenting(_ source: Source) {
        self.representingSource = source
        
        sourceLogoImageView.image = source.siteLogo
        sourceNameLabel.text = source.name
        sourceDescriptionLabel.text = source.siteDescription
        
        // Notice the user that this source is currently not available
        if !source.isEnabled {
            sourceNameLabel.text = "\(source.name) (Not Available)"
            alpha = 0.7
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        // Only allow highlighting effects when the source is enabled
        guard representingSource?.isEnabled == true else {
            return alpha = 0.7
        }
        
        UIView.animate(
            withDuration: animated ? 0.4 : 0,
            delay: 0,
            options: .curveEaseIn,
            animations: { self.alpha = highlighted ? 0.8 : 1.0 },
            completion: nil
        )
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Only allow selected effects when the source is enabled
        guard representingSource?.isEnabled == true else {
            return alpha = 0.7
        }
        
        UIView.animate(withDuration: 0.2) {
            // IBDesignable will fail to build if not opt chained
            self.sourceStateLabel?.alpha = selected ? 1.0 : 0
        }
        
        if let sourceLogoImageView = self.sourceLogoImageView {
            let borderAnimation = CABasicAnimation(keyPath: "borderWidth")
            let targetValue = CGFloat(selected ? 2.0 : 0.0)
            borderAnimation.fromValue = sourceLogoImageView.layer.borderWidth
            borderAnimation.toValue = targetValue
            borderAnimation.duration = 0.2
            sourceLogoImageView.layer.borderWidth = targetValue
            sourceLogoImageView.layer.add(borderAnimation, forKey: "com.marcuszhou.nineanimator.animation.border")
        }
    }
    
    func theme(didUpdate theme: Theme) {
        sourceStateLabel.textColor = theme.tint
        backgroundColor = .clear
        sourceLogoImageView.layer.borderColor = theme.tint.cgColor
    }
}
