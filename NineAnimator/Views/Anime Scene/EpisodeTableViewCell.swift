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

import UIKit

class EpisodeTableViewCell: UITableViewCell {
    private(set) var episodeLink: EpisodeLink?
    
    private(set) var trackingContext: TrackingContext?
    
    var onStateChange: ((EpisodeTableViewCell) -> Void)?
    
    @IBOutlet private weak var titleLabel: UILabel!
    
    @IBOutlet private weak var episodeProgressView: UIProgressView!
    
    @IBOutlet private weak var episodeProgressLabel: UILabel!
    
    @IBOutlet private weak var hidesProgressLayoutConstraint: NSLayoutConstraint!
    
    @IBOutlet private weak var offlineAccessButton: OfflineAccessButton!
    
    private var progress: Float {
        get { episodeProgressView.progress }
        set {
            let newPiority: UILayoutPriority = (newValue > 0.01) ? .defaultLow : .defaultHigh
            if newPiority != hidesProgressLayoutConstraint.priority {
                hidesProgressLayoutConstraint.priority = newPiority
                setNeedsLayout()
            }
            
            episodeProgressView.progress = newValue
            
            // Show as completed if >= 0.95
            if newValue < 0.01 {
                episodeProgressLabel.text = "Start Now"
            } else if newValue < 0.95 {
                let formatter = NumberFormatter()
                formatter.numberStyle = .percent
                formatter.maximumFractionDigits = 1
                
                episodeProgressLabel.text =
                "\(formatter.string(from: NSNumber(value: 1.0 - newValue)) ?? "Unknown percentage") left"
            } else { episodeProgressLabel.text = "Completed" }
        }
    }
    
    /// Initialize the current cell
    func setPresenting(_ episodeLink: EpisodeLink, trackingContext: TrackingContext, parent: AnimeViewController) {
        self.episodeLink = episodeLink
        self.offlineAccessButton.setPresenting(episodeLink, delegate: parent)
        
        // Remove observer first
        NotificationCenter.default.removeObserver(self)
        
        // Set name and progress
        titleLabel.text = "Episode \(episodeLink.name)"
        progress = Float(episodeLink.playbackProgress)
        
        // Add observer for progress updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onProgressUpdate),
            name: .playbackProgressDidUpdate,
            object: nil
        )
    }
    
    @objc private func onProgressUpdate() {
        guard let trackingContext = trackingContext,
              let episodeLink = episodeLink else { return }
        
        let currentProgress = Float(trackingContext.playbackProgress(for: episodeLink))
        
        print(episodeLink.playbackProgress)
        DispatchQueue.main.async {
            [weak self] in
            guard let self = self else { return }
            
            if self.progress == 0.0 && currentProgress > self.progress {
                UIView.animate(withDuration: 0.1) {
                    [weak self] in
                    guard let self = self else { return }
                    self.progress = currentProgress
                    self.setNeedsLayout()
                    self.onStateChange?(self)
                }
            } else { self.progress = currentProgress }
        }
    }
    
    func theme(didUpdate theme: Theme) {
        backgroundColor = theme.background
        titleLabel.textColor = theme.primaryText
    }
}
