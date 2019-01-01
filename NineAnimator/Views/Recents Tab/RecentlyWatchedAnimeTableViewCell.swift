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

class RecentlyWatchedAnimeTableViewCell: UITableViewCell {
    @IBOutlet private weak var coverImageView: UIImageView!
    @IBOutlet private weak var animeTitleLabel: UILabel!
    @IBOutlet private weak var sourceTitleLabel: UILabel!
    @IBOutlet private weak var notificationEnabledImage: UIImageView!
    
    var animeLink: AnimeLink? = nil {
        didSet {
            guard let link = animeLink else { return }
            coverImageView.kf.setImage(with: link.image)
            coverImageView.kf.indicatorType = .activity
            animeTitleLabel.text = link.title
            sourceTitleLabel.text = "Viewed on \(link.source.name)..."
            notificationEnabledImage.isHidden = !NineAnimator.default.user.isWatching(anime: link)
        }
    }
}
