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

class LastViewedEpisodeTableViewCell: UITableViewCell {
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var backgroundBlurredImageView: UIImageView!
    @IBOutlet weak var progressIndicator: EpisodeAccessoryProcessIndicator!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var episodeLabel: UILabel!
    @IBOutlet weak var sourceTitleLabel: UILabel!
    
    var episodeLink: EpisodeLink? = nil {
        didSet {
            guard let link = episodeLink else { return }
            let coverImageLink = link.parent.image
            coverImageView.kf.setImage(with: coverImageLink)
            coverImageView.kf.indicatorType = .activity
            backgroundBlurredImageView.kf.setImage(with: coverImageLink)
            progressIndicator.episodeLink = link
            titleLabel.text = link.parent.title
            episodeLabel.text = "Episode: \(link.name)"
            sourceTitleLabel.text = "Continue Watching on \(link.parent.source.name)..."
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let newTransform = highlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
        
        //Ignoring the animated option
        UIView.animate(withDuration: 0.2) {
            self.transform = newTransform
        }
    }
}
