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

class OfflineAnimeTableViewCell: UITableViewCell {
    var animeLink: AnimeLink? {
        didSet {
            NotificationCenter.default.removeObserver(self)
            
            guard let link = animeLink else { return }
            animeTitleLabel.text = link.title
            
            let availableEpisodes = OfflineContentManager.shared.contents(for: link).count
            availabilityLabel.text = availableEpisodes > 1 ? "\(availableEpisodes) Episodes Available Offline" :
                "1 Episode Available Offline"
            
            // Kingfisher should try to use cached data
            animePosterImageView.kf.setImage(with: link.image)
            
            // Listen to state update
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onOfflineProgressUpdate(_:)),
                name: .offlineAccessStateDidUpdate,
                object: nil
            )
            
            updateLabel()
        }
    }
    
    @IBOutlet private weak var animeTitleLabel: UILabel!
    @IBOutlet private weak var offlineStateLabel: UILabel!
    @IBOutlet private weak var availabilityLabel: UILabel!
    @IBOutlet private weak var animePosterImageView: UIImageView!
    
    @objc private func onOfflineProgressUpdate(_ notification: Notification) {
        guard let content = notification.object as? OfflineEpisodeContent,
            let link = animeLink else { return }
        
        if content.episodeLink.parent == link {
            DispatchQueue.main.async { [weak self] in self?.updateLabel() }
        }
    }
    
    private func updateLabel() {
        guard let link = animeLink else { return }
        let contents = OfflineContentManager.shared.contents(for: link)
        // Check if there are any contents that are still being downloaded
        if contents.contains(where: {
            if case .preserving = $0.state {
                return true
            } else { return false }
        }) {
            offlineStateLabel.text = "Downloading from \(link.source.name)..."
        } else { offlineStateLabel.text = "Downloaded from \(link.source.name)" }
    }
    
    deinit { NotificationCenter.default.removeObserver(self) }
}
