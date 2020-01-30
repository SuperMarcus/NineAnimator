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

class OfflineAnimeViewController: UITableViewController, BlendInViewController {
    private var presentingAnimeLink: AnimeLink?
    
    @IBOutlet private weak var headingView: UIView!
    @IBOutlet private weak var animePosterImageView: UIImageView!
    @IBOutlet private weak var animeTitleLabel: UILabel!
    @IBOutlet private weak var downloadStatusLabel: UILabel!
    
    private var contents = [OfflineEpisodeContent]()
    private var trackingContext: TrackingContext?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        let fittingHeadingViewSize = headingView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        headingView.frame.size.height = fittingHeadingViewSize.height
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let anime = presentingAnimeLink else { return }
        animePosterImageView.kf.setImage(with: anime.image)
        
        tableView.makeThemable()
        tableView.performBatchUpdates({
            contents = OfflineContentManager.shared
                .contents(for: anime)
                .sorted {
                    if NineAnimator.default.user.episodeListingOrder == .reversed {
                        return self.compareEpisodeLinks($1.episodeLink, $0.episodeLink)
                    } else { return self.compareEpisodeLinks($0.episodeLink, $1.episodeLink) }
                }
            tableView.reloadSections([ 0 ], with: .automatic)
        }, completion: nil)
        
        animeTitleLabel.text = anime.title
        updateStatistics()
        
        // Prepare the context NOW instead of on selection
        // so the context have the time to be fully prepared.
        trackingContext?.prepareContext()
        
        // Add observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onContentStateDidChange(_:)),
            name: .offlineAccessStateDidUpdate,
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Table view data source and delegate
extension OfflineAnimeViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return contents.count
        case 1: return 1
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "anime.episode", for: indexPath) as! OfflineEpisodeTableViewCell
            cell.content = contents[indexPath.item]
            return cell
        case 1: return tableView.dequeueReusableCell(withIdentifier: "anime.more", for: indexPath)
        default: fatalError("Unknown section \(indexPath.section)")
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
        ) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 0 else { return UISwipeActionsConfiguration(actions: []) }
        return UISwipeActionsConfiguration(actions: [
            UIContextualAction(style: .destructive, title: "Delete") {
                [weak self] _, _, handler in
                guard let self = self else { return }
                let content = self.contents.remove(at: indexPath.item)
                OfflineContentManager.shared.cancelPreservation(content: content)
                self.tableView.deleteRows(at: [ indexPath ], with: .fade)
                handler(true)
            }
        ])
    }
}

// MARK: - Show more episodes
extension OfflineAnimeViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let link = presentingAnimeLink else { return }
        
        if let destination = segue.destination as? AnimeViewController {
            destination.setPresenting(anime: link)
        }
    }
}

// MARK: - Statistics
extension OfflineAnimeViewController {
    @objc private func onContentStateDidChange(_ notification: Notification) {
        guard let content = notification.object as? OfflineEpisodeContent,
            let animeLink = presentingAnimeLink, content.episodeLink.parent == animeLink else { return }
        DispatchQueue.main.async { [weak self] in self?.updateStatistics() }
    }
    
    private func updateStatistics() {
        var preservedCount = 0
        var preservingCount = 0
        
        for content in contents {
            if case .preserved = content.state {
                preservedCount += 1
            }
            
            if case .preserving = content.state {
                preservingCount += 1
            }
        }
        
        var fragments = [String]()
        
        if preservingCount > 0 { fragments.append("\(preservingCount) in progress") }
        if preservedCount > 0 { fragments.append("\(preservedCount) available now") }
        
        downloadStatusLabel.text = fragments.isEmpty ? "No episodes downloaded" :
            fragments.joined(separator: ", ")
    }
}

// MARK: - Playback
extension OfflineAnimeViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectSelectedRows() }
        
        guard indexPath.section == 0 else { return }
        // Grab the content
        let content = contents[indexPath.item]
        
        switch content.state {
        case .interrupted, .error, .ready:
            OfflineContentManager.shared.initiatePreservation(content: content)
        case .preservationInitiated:
            OfflineContentManager.shared.cancelPreservation(content: content)
        case .preserving:
            OfflineContentManager.shared.suspendPreservation(content: content)
        case .preserved:
            if let media = content.media {
                NativePlayerController.default.play(media: media)
                return
            } else {
                // Present an alert stating that this episode is no longer available
                let alert = UIAlertController(
                    title: "Not Available",
                    message: "This episode is no longer available offline.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Ok", style: .cancel) {
                    _ in OfflineContentManager
                        .shared
                        .cancelPreservation(content: content)
                })
                present(alert, animated: true)
            }
        }
    }
}

// MARK: - Exposed APIs
extension OfflineAnimeViewController {
    /// Set the offline anime that this view controller
    /// should configure and present
    func setPresenting(anime: AnimeLink) {
        presentingAnimeLink = anime
        trackingContext = NineAnimator.default.trackingContext(for: anime)
    }
}

// MARK: - Compare episode link
extension OfflineAnimeViewController {
    private func compareEpisodeLinks(_ lhs: EpisodeLink, _ rhs: EpisodeLink) -> Bool {
        let lName = lhs.name
        let rName = rhs.name
        
        // Try to parse episode numbers from name
        if let lComponent = lName.split(separator: " ").first, let lNum = Int(String(lComponent)),
            let rComponent = rName.split(separator: " ").first, let rNum = Int(String(rComponent)) {
            return lNum < rNum
        } else { return lName < rName }
    }
}
