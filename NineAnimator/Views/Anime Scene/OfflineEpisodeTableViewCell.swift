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

class OfflineEpisodeTableViewCell: UITableViewCell {
    var content: OfflineEpisodeContent? {
        didSet {
            NotificationCenter.default.removeObserver(self)
            guard let content = content else { return }
            updateFromContent()
            
            // Listen to content update notification
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onProgressUpdateNotification(_:)),
                name: .offlineAccessStateDidUpdate,
                object: content
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onPlaybackProgressDidUpdate(_:)),
                name: .playbackProgressDidUpdate,
                object: nil
            )
        }
    }
    
    private func updateFromContent() {
        guard let content = content else { return }
        
        let link = content.episodeLink
        episodeNameLabel.text = "Episode \(link.name)"
        
        switch content.state {
        case .preserving(let progress):
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = 1
            formatter.percentSymbol = "%"
            progressView.setProgress(progress, animated: true)
            progressLabel.text = "Downloading (\(formatter.string(from: NSNumber(value: progress)) ?? "0%") complete)"
            downloadStatusLabel.text = "Download in Progress - \(link.parent.source.name)"
        case .preserved:
            if let date = content.datePreserved {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                formatter.dateStyle = .medium
                downloadStatusLabel.text = "Downloaded on \(formatter.string(from: date))"
            } else { downloadStatusLabel.text = "Unknown date preserved" }
            
            let playbackProgress = link.playbackProgress
            progressView.setProgress(playbackProgress, animated: true)
            
            // Update progress label if the asset is downloaded
            switch playbackProgress {
            case 0.00...0.01:
                progressLabel.text = "Start Now"
            case 0.90...:
                progressLabel.text = "Done Watching | Swipe left to delete"
            default:
                let formatter = NumberFormatter()
                formatter.numberStyle = .percent
                formatter.maximumFractionDigits = 2
                formatter.percentSymbol = "%"
                progressLabel.text = "\(formatter.string(from: NSNumber(value: 1.0 - playbackProgress)) ?? "0%") left to watch"
            }
        case .error(let error):
            progressLabel.text = "Error"
            downloadStatusLabel.text = error is NineAnimatorError ? "\(error)" : "\(error.localizedDescription)"
        case .preservationInitiated:
            progressLabel.text = "Queued"
            progressView.setProgress(0.0, animated: true)
            downloadStatusLabel.text = "Download in Progress - \(link.parent.source.name)"
        case .ready:
            progressLabel.text = "Ready for Download"
            progressView.setProgress(0.0, animated: true)
            downloadStatusLabel.text = "Unavailable for Offline Access"
        }
    }
    
    @objc private func onProgressUpdateNotification(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.updateFromContent() }
    }
    
    @objc private func onPlaybackProgressDidUpdate(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.updateFromContent() }
    }
    
    @IBOutlet private weak var episodeNameLabel: UILabel!
    @IBOutlet private weak var downloadStatusLabel: UILabel!
    @IBOutlet private weak var progressView: UIProgressView!
    @IBOutlet private weak var progressLabel: UILabel!
    
    deinit { NotificationCenter.default.removeObserver(self) }
}
