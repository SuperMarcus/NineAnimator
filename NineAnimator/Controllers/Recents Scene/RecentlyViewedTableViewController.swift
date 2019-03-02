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

class RecentlyViewedTableViewController: UITableViewController, BlendInViewController {
    /// Downloaded/downloading anime
    private lazy var statefulAnime = OfflineContentManager.shared.statefulAnime
    
    /// Third party anime tracking service lists
    private var listingServiceCollections = [ListingAnimeCollection]()
    
    /// References to async tasks
    private var taskReferencePool = [NineAnimatorAsyncTask]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        tableView.makeThemable()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //Pull any updates from the cloud
        NineAnimator.default.user.pull()
        reloadStatefulAnime()
        reloadListingServiceCollections()
        tableView.reloadData()
    }
    
    private func reloadStatefulAnime() {
        // Store the preserved or preserving anime list
        statefulAnime = OfflineContentManager.shared.statefulAnime
    }
    
    private func reloadListingServiceCollections() {
        for service in NineAnimator.default.trackingServices where service.isCapableOfRetrievingAnimeState {
            let task = service.collections().error {
                [unowned service] in
                Log.error("Did not load lists from service \"%@\": %@", service.name, $0)
            } .finally {
                [weak self, unowned service] collections in
                DispatchQueue.main.async {
                    [unowned service] in
                    guard let self = self else { return }
                    
                    // Use a batch update block
                    self.tableView.performBatchUpdates({
                        // First, update all collections that did not
                        // appear again in the latest collections
                        var variableCollections = collections
                        var indexesToDelete = [Int]()
                        
                        for (index, collection) in self.listingServiceCollections.enumerated()
                            where collection.parentService.name == service.name {
                            // If the collection exists in the presented collections,
                            // just update the value without notifying tableview
                            if let (sourceIndex, newCollection) = variableCollections
                                .enumerated()
                                .first(where: { $0.element.title == collection.title }) {
                                // Remove the collection from the source
                                _ = variableCollections.remove(at: sourceIndex)
                                self.listingServiceCollections[index] = newCollection
                            } else {
                                // Else, mark this row as deleted and remove it from
                                // the listing service collections
                                indexesToDelete.append(index)
                            }
                        }
                        
                        // Remove all marked-to-remove elements
                        self.listingServiceCollections = self.listingServiceCollections
                            .enumerated()
                            .filter { !indexesToDelete.contains($0.offset) }
                            .map { $0.element }
                        
                        // Send remove message to table view
                        self.tableView.deleteRows(
                            at: indexesToDelete.map { Section.collections[$0] },
                            with: .automatic
                        )
                        
                        // Since the use will likely be used to have collections grouped
                        // together by the services, find the index of the first occurance
                        // and insert it from there
                        let insertingIndex = self.listingServiceCollections
                            .enumerated()
                            .first { $0.element.parentService.name == service.name }?
                            .offset ?? 0
                        
                        // Make the insertion
                        variableCollections.forEach {
                            self.listingServiceCollections.insert($0, at: insertingIndex)
                        }
                        
                        // Tell the table view that we have made those insertions
                        self.tableView.insertRows(
                            at: (insertingIndex..<(insertingIndex + variableCollections.count))
                                .map { Section.collections[$0] },
                            with: .automatic
                        )
                    }, completion: nil)
                }
            }
            taskReferencePool.append(task)
        }
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
        return 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .continueWatching: return NineAnimator.default.user.lastEpisode == nil ? 0 : 1
        case .statefulAnime: return statefulAnime.count
        case .recentAnime: return NineAnimator.default.user.recentAnimes.count
        case .collections: return listingServiceCollections.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .continueWatching:
            let cell = tableView.dequeueReusableCell(withIdentifier: "recent.last", for: indexPath) as! LastViewedEpisodeTableViewCell
            cell.episodeLink = NineAnimator.default.user.lastEpisode
            return cell
        case .statefulAnime:
            let cell = tableView.dequeueReusableCell(withIdentifier: "recent.download", for: indexPath) as! OfflineAnimeTableViewCell
            cell.animeLink = statefulAnime[indexPath.item]
            return cell
        case .recentAnime:
            let cell = tableView.dequeueReusableCell(withIdentifier: "recent.anime", for: indexPath) as! RecentlyWatchedAnimeTableViewCell
            let animes = NineAnimator.default.user.recentAnimes
            let anime = animes[indexPath.item]
            cell.animeLink = anime
            return cell
        case .collections:
            let cell = tableView.dequeueReusableCell(withIdentifier: "recent.collection", for: indexPath) as! ListingCollectionEntryTableViewCell
            cell.collection = listingServiceCollections[indexPath.item]
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.makeThemable()
    }
}

// MARK: - Swipe actions
extension RecentlyViewedTableViewController {
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        var actions = [UIContextualAction]()
        
        if indexPath.section == Section.recentAnime,
            let cell = tableView.cellForRow(at: indexPath) as? RecentlyWatchedAnimeTableViewCell,
            let animeLink = cell.animeLink {
            if NineAnimator.default.user.isSubscribing(anime: animeLink) {
                let unsubscribeAction = UIContextualAction(
                    style: .normal,
                    title: "Unsubscribe"
                ) { _, _, handler in
                    NineAnimator.default.user.unsubscribe(anime: animeLink)
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
                    NineAnimator.default.user.subscribe(uncached: animeLink)
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
        // Recent anime section
        if indexPath.section == Section.recentAnime {
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
        
        // Downloads section
        if indexPath.section == Section.statefulAnime {
            let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") {
                [weak self] _, _ in
                guard let cell = tableView.cellForRow(at: indexPath) as? OfflineAnimeTableViewCell,
                    let animeLink = cell.animeLink else { return }
                OfflineContentManager.shared.removeContents(under: animeLink)
                self?.reloadStatefulAnime()
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            
            return [ deleteAction ]
        }
        
        // No actions for the others
        return []
    }
}

// MARK: - Segue preparation
extension RecentlyViewedTableViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Episodes and anime
        if let player = segue.destination as? AnimeViewController {
            if let animeCell = sender as? RecentlyWatchedAnimeTableViewCell {
                player.setPresenting(anime: animeCell.animeLink!)
            }
            
            if let episodeCell = sender as? LastViewedEpisodeTableViewCell {
                player.setPresenting(episode: episodeCell.episodeLink!)
            }
        }
        
        // If the target is an offline anime
        if let offlinePlayer = segue.destination as? OfflineAnimeViewController {
            if let animeCell = sender as? OfflineAnimeTableViewCell {
                offlinePlayer.setPresenting(anime: animeCell.animeLink!)
            }
        }
        
        // If the target is a list collection
        if let list = segue.destination as? ContentListViewController {
            if let collectionCell = sender as? ListingCollectionEntryTableViewCell {
                list.setPresenting(contentProvider: collectionCell.collection!)
            }
        }
    }
}

// MARK: - Constants
fileprivate extension RecentlyViewedTableViewController {
    // Using this enum to remind me to implement stuff when adding new sections...
    fileprivate enum Section: Int, Equatable {
        case continueWatching = 0
        
        case collections = 1
        
        case statefulAnime = 2
        
        case recentAnime = 3
        
        subscript(_ item: Int) -> IndexPath {
            return IndexPath(item: item, section: self.rawValue)
        }
        
        static func indexSet(_ sections: [Section]) -> IndexSet {
            return IndexSet(sections.map { $0.rawValue })
        }
        
        static func indexSet(_ sections: Section...) -> IndexSet {
            return IndexSet(sections.map { $0.rawValue })
        }
        
        static func == (_ lhs: Section, _ rhs: Section) -> Bool {
            return lhs.rawValue == rhs.rawValue
        }
        
        static func == (_ lhs: Int, _ rhs: Section) -> Bool {
            return lhs == rhs.rawValue
        }
        
        static func == (_ lhs: Section, _ rhs: Int) -> Bool {
            return lhs.rawValue == rhs
        }
    }
}
