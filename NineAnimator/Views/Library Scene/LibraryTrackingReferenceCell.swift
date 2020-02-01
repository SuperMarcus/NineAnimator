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

class LibraryTrackingReferenceCell: UICollectionViewCell, Themable {
    @IBOutlet private weak var animeTitleLabel: UILabel!
    @IBOutlet private weak var animeArtworkView: UIImageView!
    @IBOutlet private weak var trackingProgressStepper: UIStepper!
    @IBOutlet private weak var trackingProgressLabel: UILabel!
    @IBOutlet private weak var seperatorLineView: UIView!
    @IBOutlet private weak var progressBar: UIProgressView!
    @IBOutlet private weak var accessorySubtitleLabel: UILabel!
    
    private(set) var reference: ListingAnimeReference?
    private(set) var tracking: ListingAnimeTracking?
    private weak var delegate: LibraryTrackingCollectionController?
    
    /// Initialize this cell with tracking information
    func setPresenting(_ reference: ListingAnimeReference, tracking: ListingAnimeTracking, delegate: LibraryTrackingCollectionController) {
        self.reference = reference
        self.tracking = tracking
        self.delegate = delegate
        
        // Update UI components
        self.animeTitleLabel.text = reference.name
        self.animeArtworkView.kf.setImage(
            with: reference.artwork ?? NineAnimator.placeholderArtworkUrl
        )
        self.trackingProgressStepper.value = Double(tracking.currentProgress)
        self.trackingProgressStepper.minimumValue = 0
        
        if let totalEpisodes = tracking.episodes, totalEpisodes > 0 {
            trackingProgressLabel.text = "\(tracking.currentProgress) of \(totalEpisodes)"
            self.trackingProgressStepper.maximumValue = Double(totalEpisodes)
            self.progressBar.isHidden = false
            self.progressBar.progress = Float(tracking.currentProgress) / Float(totalEpisodes)
        } else {
            trackingProgressLabel.text = "\(tracking.currentProgress)"
            self.trackingProgressStepper.maximumValue = 7071
            self.progressBar.isHidden = true
        }
    }
    
    @IBAction private func onStepperValueDidChange(_ sender: UIStepper) {
        guard let tracking = tracking, let reference = reference else { return }
        let newProgress = Int(sender.value)
        
        // Show the total number of episodes in the label
        if let totalEpisodes = tracking.episodes, totalEpisodes > 0 {
            trackingProgressLabel.text = "\(newProgress) of \(totalEpisodes)"
            progressBar.setProgress(Float(newProgress) / Float(totalEpisodes), animated: true)
        } else { trackingProgressLabel.text = "\(newProgress)" }
        
        // Obtain the next tracking state and update it
        let newTracking = tracking.newTracking(withUpdatedProgress: newProgress)
        reference.parentService.update(reference, newTracking: newTracking)
    }
    
    func didResolve(relatedTrackingContexts contexts: [TrackingContext]) {
        let mostRecentRecord = contexts.compactMap {
            $0.mostRecentRecord
        } .max { a, b in a.enqueueDate < b.enqueueDate }
        
        if let mostRecentRecord = mostRecentRecord {
            let interval = Date().timeIntervalSince(mostRecentRecord.enqueueDate)
            let intervalLabel = interval.durationDescription
            
            // Update label
            accessorySubtitleLabel.text = "ep. \(mostRecentRecord.episodeNumber) streamed \(intervalLabel)".uppercased()
        } else { accessorySubtitleLabel.text = "no local records found".uppercased() }
    }
    
    func theme(didUpdate theme: Theme) {
        seperatorLineView.backgroundColor = theme.seperator
        progressBar.progressTintColor = theme.secondaryText
        progressBar.trackTintColor = theme.secondaryBackground
        updateTouchReactionTint()
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
