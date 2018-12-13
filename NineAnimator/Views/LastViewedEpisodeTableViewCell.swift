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
import Kingfisher

class LastViewedEpisodeTableViewCell: UITableViewCell {
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var backgroundBlurredImageView: UIImageView!
    @IBOutlet weak var progressIndicator: EpisodeAccessoryProcessIndicator!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var episodeLabel: UILabel!
    
    var episodeLink: EpisodeLink? = nil {
        didSet {
            guard let link = episodeLink else { return }
            let coverImageLink = link.parent.image
            coverImageView.kf.setImage(with: coverImageLink)
            backgroundBlurredImageView.kf.setImage(with: coverImageLink)
            progressIndicator.episodeLink = link
            titleLabel.text = link.parent.title
            episodeLabel.text = "Episode: \(link.name)"
        }
    }
}
