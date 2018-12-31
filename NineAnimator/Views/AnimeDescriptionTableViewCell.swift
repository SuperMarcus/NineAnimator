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

import Kingfisher
import UIKit

class AnimeDescriptionTableViewCell: UITableViewCell {
    @IBOutlet weak var backgroundBlurredImageView: UIImageView!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var descriptionText: UITextView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    var animeDescription: String? {
        willSet {
            guard let newValue = newValue else {
                descriptionText.isHidden = true
                loadingIndicator.isHidden = false
                loadingIndicator.startAnimating()
                return
            }
            
            UIView.transition(with: loadingIndicator, duration: 0.3, options: .curveEaseOut, animations: { [weak self] in
                guard let self = self else { return }
                self.descriptionText.text = newValue
                self.descriptionText.setContentOffset(.zero, animated: false)
                self.descriptionText.isHidden = false
                self.loadingIndicator.stopAnimating()
                self.loadingIndicator.isHidden = true
            })
        }
    }
    
    var link: AnimeLink? {
        didSet {
            guard let link = link else { return }
            backgroundBlurredImageView.kf.setImage(with: link.image)
            coverImageView.kf.setImage(with: link.image)
            coverImageView.kf.indicatorType = .activity
        }
    }
}
