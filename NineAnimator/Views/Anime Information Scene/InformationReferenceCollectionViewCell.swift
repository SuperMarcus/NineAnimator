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

class InformationReferenceCollectionViewCell: UICollectionViewCell {
    @IBOutlet private weak var artworkImageView: UIImageView!
    @IBOutlet private weak var referenceNameLabel: UILabel!
    
    private(set) var reference: ListingAnimeReference?
    
    func initialize(_ reference: ListingAnimeReference) {
        self.reference = reference
        
        // Load image
        artworkImageView.alpha = 0.0
        artworkImageView.kf.setImage(with: reference.artwork, completionHandler: {
            [weak artworkImageView] _ in UIView.animate(withDuration: 0.2) {
                artworkImageView?.alpha = 1.0
            }
        })
        
        // Set name
        referenceNameLabel.text = reference.name
    }
    
    override var isSelected: Bool {
        get { super.isSelected }
        set {
            super.isSelected = newValue
            
            // Animate background color
            UIView.animate(withDuration: 0.2) {
                if newValue {
                    self.backgroundColor = UIColor.black.withAlphaComponent(0.2)
                } else { self.backgroundColor = .clear }
            }
        }
    }
}
