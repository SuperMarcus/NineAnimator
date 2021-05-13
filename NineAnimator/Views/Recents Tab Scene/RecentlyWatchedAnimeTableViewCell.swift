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
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources
import UIKit

class RecentlyWatchedAnimeTableViewCell: UITableViewCell, Themable {
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
            notificationEnabledImage.isHidden = !NineAnimator.default.user.isSubscribing(anime: link)
            
            UserNotificationManager.default.hasNotifications(for: link) { hasNotification, _ in
                guard let hasNotification = hasNotification else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.notificationEnabledImage.tintColor = hasNotification ? UIColor.red : Theme.current.secondaryText
                }
            }
        }
    }
    
    func theme(didUpdate theme: Theme) {
        animeTitleLabel.textColor = theme.primaryText
        sourceTitleLabel.textColor = theme.primaryText
    }
}
