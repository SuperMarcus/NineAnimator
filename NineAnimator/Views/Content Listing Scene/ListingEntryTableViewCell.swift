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

class ListingEntryTableViewCell: UITableViewCell, Themable {
    @IBOutlet private weak var coverImageView: UIImageView!
    @IBOutlet private weak var animeTitleLabel: UILabel!
    
    var link: AnyLink? {
        didSet {
            guard let link = self.link else { return }
            
            // Set the title label
            animeTitleLabel.text = link.name
            
            // Load the image if it exists
            if let artworkUrl = link.artwork {
                coverImageView.kf.setImage(with: artworkUrl)
                coverImageView.kf.indicatorType = .activity
            }
        }
    }
    
    func theme(didUpdate theme: Theme) {
        backgroundColor = theme.background
        animeTitleLabel.textColor = theme.primaryText
    }
}
