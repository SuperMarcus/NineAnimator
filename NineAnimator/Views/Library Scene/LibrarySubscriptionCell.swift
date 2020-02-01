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

class LibrarySubscriptionCell: UICollectionViewCell {
    @IBOutlet private weak var artworkImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var accessorySubtitleLabel: UILabel!
    @IBOutlet private weak var updateStatusLabel: UILabel!
    @IBOutlet private weak var sourceLabel: UILabel!
    
    private(set) var representingLink: AnyLink?
    private(set) var notificationFetchingTask: NineAnimatorAsyncTask?
    
    func setPresenting(_ link: AnyLink) {
        // Store the links and set the approperiate labels/images
        self.representingLink = link
        self.titleLabel.text = link.name
        self.artworkImageView.kf.setImage(with: link.artwork ?? NineAnimator.placeholderArtworkUrl)
        
        // Set the source label to the approperiate value
        switch link {
        case let .anime(animeLink):
            sourceLabel.text = animeLink.source.name
        case let .listingReference(reference):
            sourceLabel.text = reference.parentService.name
        default:
            sourceLabel.text = "Unsupported"
            Log.error("[LibrarySubscriptionCell] Trying to present a link that is not supported for subscription: %@", link)
        }
    }
    
    func updateSubtitleInformation() {
        guard let link = self.representingLink else { return }
        
        switch link {
        case let .anime(animeLink):
            let context = NineAnimator.default.trackingContext(for: animeLink)
            
            if let record = context.furtherestEpisodeRecord {
                let durationDescription = Date()
                    .timeIntervalSince(record.enqueueDate)
                    .durationDescription
                accessorySubtitleLabel.text = "Ep. \(record.episodeNumber) streamed \(durationDescription)"
                    .uppercased()
                
                if let watcher = UserNotificationManager.default.retrive(for: animeLink) {
                    let totalEpisodes = watcher.episodeNames.count
                    self.updateStatusLabel.text = "Ep. \(record.episodeNumber) / \(totalEpisodes)"
                } else {
                    self.updateStatusLabel.text = "Ep. \(record.episodeNumber)"
                }
            }
            
            // May want to re-design this in the near future
            notificationFetchingTask = UserNotificationManager
                .default
                .hasNotifications(for: animeLink)
                .dispatch(on: .main)
                .error {
                    [weak self] error in
                    Log.error("[LibrarySubscriptionCell] An unknown error has occurred that prevents the retrival of available states: %@", error)
                    self?.updateStatusLabel.text = "Unknwon"
                } .finally {
                    [weak self] hasNewEpisode in
                    guard let self = self else { return }
                    
                    // Update the accessory label
                    if hasNewEpisode {
                        // A known problem for this is that once the appearance changes
                        // the Theme might override this text color
                        self.accessorySubtitleLabel.textColor = UIColor.orange
                        self.accessorySubtitleLabel.text = "New episode available"
                    } else {
                        self.accessorySubtitleLabel.textColor = Theme.current.secondaryText
                    }
                }
        default:
            updateStatusLabel.text = "Unknown"
            accessorySubtitleLabel.text = "Unsupported subscription"
            Log.error("[LibrarySubscriptionCell] Trying to present a link that is not supported for subscription: %@", link)
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
