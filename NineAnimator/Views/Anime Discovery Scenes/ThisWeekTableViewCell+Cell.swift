//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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

class ThisWeekCellCollectionViewCell: UICollectionViewCell {
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var synopsisLabel: UILabel!
    @IBOutlet private weak var captionLabel: UILabel!
    @IBOutlet private weak var artworkImageView: UIImageView!
    @IBOutlet private weak var captionContainerView: UIView!
    
    private(set) var recommendingItem: RecommendingItem?
    
    func setPresenting(_ item: RecommendingItem) {
        self.recommendingItem = item
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        synopsisLabel.text = item.synopsis
        captionLabel.text = item.caption
        artworkImageView.kf.setImage(with: item.artwork)
        
        // Set appropriate caption background color
        captionContainerView.backgroundColor = item.captionStyle == .highlight ? #colorLiteral(red: 1, green: 0.3098039216, blue: 0.2666666667, alpha: 1) : .clear
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

extension ThisWeekTableViewCell {
    typealias Cell = ThisWeekCellCollectionViewCell
}
