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

import UIKit

@IBDesignable
class DetailedEpisodeTableViewCell: UITableViewCell {
    @IBOutlet private weak var episodeSubtitleLabel: UILabel!
    
    @IBOutlet private weak var episodeNameLabel: UILabel!
    
    @IBOutlet private weak var episodeSynopsisLabel: UILabel!
    
    @IBOutlet private weak var episodePlaybackProgressView: UIProgressView!
    
    @IBOutlet private weak var episodePlaybackProgressLabel: UILabel!
    
    @IBOutlet private weak var hideProgressViewConstraint: NSLayoutConstraint!
    
    @IBOutlet private weak var offlineAccessButton: OfflineAccessButton!
    
    // Callback that is invoked when the progress view is becoming hidden/presented
    var onStateChange: ((DetailedEpisodeTableViewCell) -> Void)?
    
    var episodeLink: EpisodeLink? {
        didSet { offlineAccessButton.episodeLink = episodeLink }
    }
    
    var episodeInformation: Anime.AdditionalEpisodeLinkInformation? {
        didSet {
            // Remove observation first
            NotificationCenter.default.removeObserver(self)
            
            guard let info = episodeInformation else { return }
            
            if episodeLink == nil { episodeLink = info.parent }
            
            // Title
            
            episodeNameLabel.text = info.title ?? "Untitled"
            
            // Subtitle
            
            var subtitleContents = [String]()
            
            if let episodeNumber = info.episodeNumber {
                subtitleContents.append("Episode \(episodeNumber)")
            }
            
            if let airDate = info.airDate {
                subtitleContents.append("Aired on \(airDate)")
            }
            
            let subtitle = subtitleContents.joined(separator: " | ")
            
            episodeSubtitleLabel.text = subtitle
            
            // Synopsis
            
            episodeSynopsisLabel.text = info.synopsis ?? "No synoposis found for this episode."
            
            // Progress
            
            progress = Float(info.parent.playbackProgress)
            
            // Listen to progress updates
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onProgressUpdate),
                name: .playbackProgressDidUpdate,
                object: nil
            )
        }
    }
    
    private var progress: Float {
        get { return episodePlaybackProgressView.progress }
        set {
            let newPiority: UILayoutPriority = (newValue > 0.01) ? .defaultLow : .defaultHigh
            if newPiority != hideProgressViewConstraint.priority {
                hideProgressViewConstraint.priority = newPiority
                setNeedsLayout()
            }
            
            episodePlaybackProgressView.progress = newValue
            
            if newValue < 0.95 {
                let formatter = NumberFormatter()
                formatter.numberStyle = .percent
                formatter.maximumFractionDigits = 1
                
                episodePlaybackProgressLabel.text =
                "\(formatter.string(from: NSNumber(value: 1.0 - newValue)) ?? "Unknown percentage") left"
            } else { episodePlaybackProgressLabel.text = "Completed" }
        }
    }
    
    @objc private func onProgressUpdate() {
        guard let episodeLink = episodeLink else { return }
        
        let currentProgress = Float(episodeLink.playbackProgress)
        
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
    
    deinit { NotificationCenter.default.removeObserver(self) }
}
