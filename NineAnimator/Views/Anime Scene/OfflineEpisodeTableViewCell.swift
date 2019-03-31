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
    
    // This is to make sure that we don't update the UI too frequently,
    // which might cause some performance issues
    private var _lastProgressUpdateData = Date.distantPast
    
    // swiftlint:disable cyclomatic_complexity
    private func updateFromContent() {
        guard let content = content else { return }
        let link = content.episodeLink
        
        switch content.state {
        case .preserving(let progress):
            // Once every one second at most
            guard _lastProgressUpdateData.timeIntervalSinceNow < -1.0 else { break }
            _lastProgressUpdateData = Date()
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = 1
            formatter.percentSymbol = "%"
            
            // If the download is immedietly available, reflect that in the download
            // status label
            updateLabels(
                status: "Download in Progress - \(link.parent.source.name)",
                progressStatus: "Downloading (\(formatter.string(from: NSNumber(value: progress)) ?? "0%") complete)",
                progress: progress
            )
        case .preserved:
            let downloadStatus: String
            if let date = content.datePreserved {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                formatter.dateStyle = .medium
                downloadStatus = "Downloaded on \(formatter.string(from: date)) from \(link.parent.source.name)"
            } else { downloadStatus = "Unknown date preserved" }
            
            let playbackProgress = link.playbackProgress
            let progressLabelText: String
            // Update progress label if the asset is downloaded
            switch playbackProgress {
            case 0.00...0.01:
                progressLabelText = "Start Now"
            case 0.90...:
                progressLabelText = "Done Watching | Swipe left to delete"
            default:
                let formatter = NumberFormatter()
                formatter.numberStyle = .percent
                formatter.maximumFractionDigits = 2
                formatter.percentSymbol = "%"
                progressLabelText = "\(formatter.string(from: NSNumber(value: 1.0 - playbackProgress)) ?? "0%") left to watch"
            }
            
            updateLabels(
                status: downloadStatus,
                progressStatus: progressLabelText,
                progress: Float(playbackProgress)
            )
        case .error(let error):
            updateLabels(
                status: (error as NSError).localizedFailureReason ?? error.localizedDescription,
                progressStatus: "Error | Tap to Retry"
            )
        case .preservationInitiated:
            updateLabels(
                status: "Download in Progress - \(link.parent.source.name)",
                progressStatus: "Queued",
                progress: 0.0
            )
        case .ready:
            updateLabels(
                status: "Ready for Download - \(link.parent.source.name)",
                progressStatus: "Ready | Tap to Start",
                progress: 0.0
            )
        case .interrupted:
            updateLabels(
                status: "Ready to Resume Download - \(link.parent.source.name)",
                progressStatus: "Suspended | Tap to Resume",
                progress: 0.0
            )
        }
    }
    // swiftlint:enable cyclomatic_complexity
    
    private func updateLabels(status: String, progressStatus: String, progress: Float? = nil) {
        DispatchQueue.main.async {
            [weak self] in
            // Update episode name
            if let link = self?.content?.episodeLink {
                self?.episodeNameLabel.text = "Episode \(link.name)"
            }
            
            // Update labels
            self?.progressLabel.text = progressStatus
            self?.downloadStatusLabel.text = status
            
            // Update progress view
            if let progress = progress {
                self?.progressView.setProgress(progress, animated: true)
            }
        }
    }
    
    @objc private func onProgressUpdateNotification(_ notification: Notification) {
        DispatchQueue.global().async { [weak self] in self?.updateFromContent() }
    }
    
    @objc private func onPlaybackProgressDidUpdate(_ notification: Notification) {
        DispatchQueue.global().async { [weak self] in self?.updateFromContent() }
    }
    
    @IBOutlet private weak var episodeNameLabel: UILabel!
    @IBOutlet private weak var downloadStatusLabel: UILabel!
    @IBOutlet private weak var progressView: UIProgressView!
    @IBOutlet private weak var progressLabel: UILabel!
    
    deinit { NotificationCenter.default.removeObserver(self) }
}
