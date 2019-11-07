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

class LibraryRecentlyWatchedCell: UICollectionViewCell {
    @IBOutlet private weak var artworkImageView: UIImageView!
    @IBOutlet private weak var animeTitleLabel: UILabel!
    @IBOutlet private weak var progressLabel: UILabel!
    
    private(set) var animeLink: AnimeLink?
    
    // Holding the reference to the tracking context
    private var context: TrackingContext?
    
    func setPresenting(_ animeLink: AnimeLink) {
        self.animeLink = animeLink
        self.artworkImageView.kf.setImage(with: animeLink.image)
        self.animeTitleLabel.text = animeLink.title
        
        let context = NineAnimator.default.trackingContext(for: animeLink)
        self.context = context
        
        // It is faster to get the most recent record
        if let record = context.mostRecentRecord {
            progressLabel.text = "Ep. \(record.episodeNumber)"
        } else { progressLabel.text = "???" }
    }
    
    override var isHighlighted: Bool {
        didSet { updateTouchReactionTint() }
    }
    
    override var isSelected: Bool {
        didSet { updateTouchReactionTint() }
    }
    
    private func updateTouchReactionTint() {
        let shouldTint = isHighlighted || isSelected
        alpha = shouldTint ? 0.4 : 1
    }
}
