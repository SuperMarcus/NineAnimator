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

class RecentlyViewedTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        tableView.makeThemable()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //Pull any updates from the cloud
        NineAnimator.default.user.pull()
        tableView.reloadData()
    }
}

extension RecentlyViewedTableViewController {
    @IBAction private func onCastButtonPressed(_ sender: Any) {
        CastController.default.presentPlaybackController()
    }
}

// MARK: - Table view data source
extension RecentlyViewedTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return NineAnimator.default.user.lastEpisode == nil ? 0 : 1
        case 1: return NineAnimator.default.user.recentAnimes.count
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return traitCollection.verticalSizeClass == .compact
            || traitCollection.horizontalSizeClass == .compact
            ? 160 : 200
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "recent.last", for: indexPath) as! LastViewedEpisodeTableViewCell
            cell.episodeLink = NineAnimator.default.user.lastEpisode
            cell.makeThemable()
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "recent.anime", for: indexPath) as! RecentlyWatchedAnimeTableViewCell
            let animes = NineAnimator.default.user.recentAnimes
            let anime = animes[indexPath.item]
            cell.animeLink = anime
            cell.makeThemable()
            return cell
        default: fatalError("unimplemented section (\(indexPath.section))")
        }
    }
}

// MARK: - Swipe actions
extension RecentlyViewedTableViewController {
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        var actions = [UIContextualAction]()
        
        if indexPath.section == 1,
            let cell = tableView.cellForRow(at: indexPath) as? RecentlyWatchedAnimeTableViewCell,
            let animeLink = cell.animeLink {
            if NineAnimator.default.user.isWatching(anime: animeLink) {
                let unsubscribeAction = UIContextualAction(
                    style: .normal,
                    title: "Unsubscribe"
                ) { _, _, handler in
                    NineAnimator.default.user.unwatch(anime: animeLink)
                    cell.animeLink = animeLink // This forces the cell to display the bell icon accordinly
                    handler(true)
                }
                unsubscribeAction.backgroundColor = UIColor.orange
                unsubscribeAction.image = #imageLiteral(resourceName: "Notification Disabled")
                actions.append(unsubscribeAction)
            } else {
                let subscribeAction = UIContextualAction(
                    style: .normal,
                    title: "Subscribe"
                ) { _, _, handler in
                    UserNotificationManager.default.requestNotificationPermissions()
                    NineAnimator.default.user.watch(uncached: animeLink)
                    cell.animeLink = animeLink
                    handler(true)
                }
                subscribeAction.backgroundColor = UIColor.orange
                subscribeAction.image = #imageLiteral(resourceName: "Notification Enabled")
                actions.append(subscribeAction)
            }
        }
        
        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if indexPath.section == 1 {
            let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") {
                _, _ in
                guard let cell = tableView.cellForRow(at: indexPath) as? RecentlyWatchedAnimeTableViewCell,
                    let animeLink = cell.animeLink else { return }
                NineAnimator.default.user.recentAnimes = NineAnimator.default.user.recentAnimes.filter {
                    $0 != animeLink
                }
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            
            let shareAction = UITableViewRowAction(style: .normal, title: "Share") {
                [weak self] _, _ in
                guard let cell = tableView.cellForRow(at: indexPath) as? RecentlyWatchedAnimeTableViewCell,
                    let animeLink = cell.animeLink else { return }
                
                let activityViewController = UIActivityViewController(
                    activityItems: [ animeLink.link ], applicationActivities: nil
                )
                
                if let popover = activityViewController.popoverPresentationController {
                    popover.sourceView = cell
                    popover.permittedArrowDirections = .any
                }
                
                self?.present(activityViewController, animated: true)
            }
            
            shareAction.backgroundColor = #colorLiteral(red: 0, green: 0.4784313725, blue: 1, alpha: 1)
            
            return [ deleteAction, shareAction ]
        }
        return []
    }
}

// MARK: - Segue preparation
extension RecentlyViewedTableViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let player = segue.destination as? AnimeViewController else { return }
        
        if let animeCell = sender as? RecentlyWatchedAnimeTableViewCell {
            player.setPresenting(anime: animeCell.animeLink!)
        }
        
        if let episodeCell = sender as? LastViewedEpisodeTableViewCell {
            player.setPresenting(episode: episodeCell.episodeLink!)
        }
    }
}
