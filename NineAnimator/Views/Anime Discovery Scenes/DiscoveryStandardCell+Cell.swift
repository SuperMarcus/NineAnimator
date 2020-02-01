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

import Kingfisher
import UIKit

class DiscoveryStandardCellCollectionViewCell: UICollectionViewCell {
    @IBOutlet private weak var artworkImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var captionLabel: UILabel!
    @IBOutlet private weak var captionBackgroundView: UIVisualEffectView!
    
    private(set) var recommendingItem: RecommendingItem?
    
    func setPresenting(_ item: RecommendingItem) {
        self.recommendingItem = item
        
        artworkImageView.kf.setImage(with: item.artwork)
        titleLabel.text = item.title
        captionLabel.text = item.caption
        captionBackgroundView.isHidden = item.caption.isEmpty
        
        if case .highlight = item.captionStyle {
            captionBackgroundView.contentView.backgroundColor = #colorLiteral(red: 1, green: 0.3098039216, blue: 0.2666666667, alpha: 1)
            captionLabel.disableTheming = true
            captionLabel.textColor = .white
        } else {
            captionBackgroundView.contentView.backgroundColor = .clear
            captionLabel.disableTheming = false
            captionLabel.makeThemable()
        }
    }
    
    override var isHighlighted: Bool {
        get { super.isHighlighted }
        set {
            super.isHighlighted = newValue
            if newValue {
                alpha = 0.6
            } else { alpha = 1.0 }
        }
    }
}

extension DiscoveryStandardTableViewCell {
    typealias Cell = DiscoveryStandardCellCollectionViewCell
}
