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

class LibraryRecentAnimeCell: UICollectionViewCell {
    @IBOutlet private weak var animeArtworkImageView: UIImageView!
    @IBOutlet private weak var animeTitleLabel: UILabel!
    @IBOutlet private weak var accessorySubtitleLabel: UILabel!
    @IBOutlet private weak var animeSourceLabel: UILabel!
    @IBOutlet private weak var animeProgressLabel: UILabel!
    
    private(set) var animeLink: AnimeLink?
    private(set) var trackingContext: TrackingContext?
    
    func setPresenting(_ animeLink: AnimeLink) {
        self.animeLink = animeLink
        self.animeArtworkImageView.kf.setImage(with: animeLink.image)
        self.animeTitleLabel.text = animeLink.title
        self.animeSourceLabel.text = animeLink.source.name
        
        // Obtain and hold the reference to the TrackingContext
        let context = NineAnimator.default.trackingContext(for: animeLink)
        self.trackingContext = context
        self.updateAccessoryLabel()
        self.pointerEffect.hover(scale: true)
    }
    
    func updateAccessoryLabel() {
        if let latestRecord = trackingContext?.mostRecentRecord,
            let furtherestRecord = trackingContext?.furtherestEpisodeRecord {
            let duration = Date().timeIntervalSince(latestRecord.enqueueDate)
            accessorySubtitleLabel.text = "Streamed \(duration.durationDescription)".uppercased()
            animeProgressLabel.text = "Ep. \(furtherestRecord.episodeNumber)"
        } else {
            accessorySubtitleLabel.text = "Haven't Watched".uppercased()
            animeProgressLabel.text = "No Records"
        }
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
