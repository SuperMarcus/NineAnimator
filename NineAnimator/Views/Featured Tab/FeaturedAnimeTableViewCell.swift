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

class FeaturedAnimeTableViewCell: UITableViewCell {
    @IBOutlet private weak var animeImageView: UIImageView!
    
    @IBOutlet private weak var animeTitleLabel: UILabel!
    
    func setAnime(_ animeLink: AnimeLink) {
        animeTitleLabel.text = animeLink.title
        animeImageView.kf.setImage(with: animeLink.image)
        animeImageView.kf.indicatorType = .activity
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let newTransform = highlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
        
        UIView.animate(withDuration: 0.2) {
            self.transform = newTransform
        }
    }
}
