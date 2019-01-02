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

import AVKit
import SafariServices
import UIKit
import UserNotifications
import WebKit

/**
 NineAnimator's one and only `AnimeViewController`
 
 - important:
 Always initalize this class from storyboard and use the `setPresenting(_: AnimeLink)`
 method or the `setPresenting(episode: EpisodeLink)` method to initialize before
 presenting.
 
 ## Example Usage
 
 1. Create segues in storyboard with reference to `AnimePlayer.storyboard`.
 2. Override `prepare(for segue: UIStoryboardSegue)` method.
 3. Retrive the `AnimeViewController` from `segue.destination as? AnimeViewController`
 4. Initialize the `AnimeViewController` with either `setPresenting(_: AnimeLink)` or
    `setPresenting(episode: EpisodeLink)`.
 */
class AnimeViewController: UITableViewController, ServerPickerSelectionDelegate, AVPlayerViewControllerDelegate {
    // MARK: - Set either one of the following item to initialize the anime view
    private var animeLink: AnimeLink?
    
    private var episodeLink: EpisodeLink? {
        didSet {
            if let episodeLink = episodeLink {
                self.animeLink = episodeLink.parent
                self.server = episodeLink.server
            }
        }
    }
    
    // MARK: - Managed by AnimeViewController
    @IBOutlet private weak var serverSelectionButton: UIBarButtonItem!
    
    @IBOutlet private weak var notificationToggleButton: UIBarButtonItem!
    
    private var anime: Anime? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.informationCell?.animeDescription = self.anime?.description
                
                self.updateNotificationToggle()
                
                let sectionsNeededReloading: IndexSet = [1]
                
                if self.anime == nil && oldValue != nil {
                    self.tableView.deleteSections(sectionsNeededReloading, with: .fade)
                }
                
                guard let anime = self.anime else { return }
                
                if self.server == nil {
                    if let recentlyUsedServer = UserDefaults.standard.string(forKey: "server.recent"),
                        anime.servers[recentlyUsedServer] != nil {
                        self.server = recentlyUsedServer
                    } else {
                        self.server = anime.servers.first!.key
                        Log.info("No server selected. Using %@", anime.servers.first!.key)
                    }
                }
                
                self.serverSelectionButton.title = anime.servers[self.server!]
                self.serverSelectionButton.isEnabled = true
                
                if oldValue == nil {
                    self.tableView.insertSections(sectionsNeededReloading, with: .fade)
                } else {
                    self.tableView.reloadSections(sectionsNeededReloading, with: .fade)
                }
            }
        }
    }
    
    var server: Anime.ServerIdentifier?
    
    // Set episode will update the server identifier as well
    private var episode: Episode? {
        didSet {
            guard let episode = episode else { return }
            server = episode.link.server
        }
    }
    
    private var informationCell: AnimeDescriptionTableViewCell?
    
    private var selectedEpisodeCell: EpisodeTableViewCell?
    
    private var episodeRequestTask: NineAnimatorAsyncTask?
    
    private var animeRequestTask: NineAnimatorAsyncTask?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Remove lines at the end of the table
        tableView.tableFooterView = UIView()
        
        // If episode is set, use episode's anime link as the anime for display
        if let episode = episode {
            animeLink = episode.parentLink
        }
        
        guard let link = animeLink else { return }
        // Update history
        NineAnimator.default.user.entering(anime: link)
        NineAnimator.default.user.push()
        
        //Update anime title
        title = link.title
        
        // Fetch anime if anime does not exists
        guard anime == nil else { return }
        serverSelectionButton.title = "Select Server"
        serverSelectionButton.isEnabled = false
        
        notificationToggleButton.isEnabled = false
        
        animeRequestTask = NineAnimator.default.anime(with: link) {
            [weak self] anime, error in
            guard let anime = anime else { return Log.error(error) }
            self?.anime = anime
            // Initiate playback if episodeLink is set
            if self?.episodeLink != nil {
                self?.retriveAndPlay()
            }
        }
    }
    
    override func didMove(toParent parent: UIViewController?) {
        // Cleanup observers and tasks
        episodeRequestTask?.cancel()
        episodeRequestTask = nil
        
        //Sets episode and server to nil
        episode = nil
        
        //Remove all observations
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Exposed Interfaces
extension AnimeViewController {
    /**
     Initialize the `AnimeViewController` with the provided
     AnimeLink.
     
     - parameters:
        - link: The `AnimeLink` object that is used to
                initialize this `AnimeViewController`
     
     By calling this method, `AnimeViewController` will use the
     Source object from this link to retrive the `Anime` object.
     */
    func setPresenting(_ link: AnimeLink) {
        self.episodeLink = nil
        self.animeLink = link
    }
    
    /**
     Initialize the `AnimeViewController` with the parent AnimeLink
     of the provided `EpisodeLink`, and immedietly starts playing
     the episode once the anime is retrived and parsed.
     
     - parameters:
        - episode: The `EpisodeLink` object that is used to
                   initialize this `AnimeViewController`
     
     `AnimeViewController` will first retrive the Anime object from
     the Source in `AnimeViewController.viewWillAppear`
     */
    func setPresenting(episode link: EpisodeLink) {
        self.episodeLink = link
    }
}

// MARK: - Table view data source
extension AnimeViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return anime == nil ? 1 : 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            guard let serverIdentifier = server,
                let episodes = anime?.episodes[serverIdentifier]
                else { return 0 }
            return episodes.count
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "anime.description") as! AnimeDescriptionTableViewCell
            cell.link = animeLink
            cell.animeDescription = anime?.description
            informationCell = cell
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "anime.episode") as! EpisodeTableViewCell
            let episodes = anime!.episodes[server!]!
            var episode = episodes[indexPath.item]
            
            if NineAnimator.default.user.episodeListingOrder == .reversed {
                episode = episodes[episodes.count - indexPath.item - 1]
            }
            
            cell.episodeLink = episode
            return cell
        default:
            fatalError("Anime view don't have section \(indexPath.section)")
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? EpisodeTableViewCell else {
            Log.error("Cell selection event received (from %@) when the cell selected is not an EpisodeTableViewCell", indexPath)
            return
        }
        
        guard cell != selectedEpisodeCell,
            let episodeLink = cell.episodeLink
            else { return }
        
        selectedEpisodeCell = cell
        self.episodeLink = episodeLink
        retriveAndPlay()
    }
    
    func didSelectServer(_ server: Anime.ServerIdentifier) {
        self.server = server
        UserDefaults.standard.set(server, forKey: "server.recent")
        tableView.reloadSections([1], with: .automatic)
        serverSelectionButton.title = anime!.servers[server]
    }
}

// MARK: - Share/Select Server/Notifications
extension AnimeViewController {
    @IBAction private func onCastButtonTapped(_ sender: Any) {
        RootViewController.shared?.showCastController()
    }
    
    @IBAction private func onActionButtonTapped(_ sender: UIBarButtonItem) {
        guard let link = animeLink else { return }
        let activityViewController = UIActivityViewController(activityItems: [link.link], applicationActivities: nil)
        
        if let popover = activityViewController.popoverPresentationController {
            popover.barButtonItem = sender
            popover.permittedArrowDirections = .up
        }
        
        present(activityViewController, animated: true)
    }
    
    @IBAction private func onServerButtonTapped(_ sender: Any) {
        let alertView = UIAlertController(title: "Select Server", message: nil, preferredStyle: .actionSheet)
        
        if let popover = alertView.popoverPresentationController {
            popover.barButtonItem = serverSelectionButton
            popover.permittedArrowDirections = .up
        }
        
        for server in anime!.servers {
            let action = UIAlertAction(title: server.value, style: .default) {
                [weak self] _ in
                self?.didSelectServer(server.key)
            }
            if self.server == server.key {
                action.setValue(true, forKey: "checked")
            }
            alertView.addAction(action)
        }
        alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertView, animated: true)
    }
    
    @IBAction private func onToggleNotification(_ sender: Any) {
        guard let anime = anime else { return }
        
        if NineAnimator.default.user.isWatching(anime) {
            NineAnimator.default.user.unwatch(anime: anime)
        } else {
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.requestAuthorization(options: [.badge]) {
                [weak self] success, _ in
                if !success {
                    let alertController = UIAlertController(title: "Updates Unavailable", message: "NineAnimator doesn't have persmission to send notifications. You won't receive any updates for this anime until you allow notifications from NineAnimator in Settings.", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self?.present(alertController, animated: true)
                }
            }
            NineAnimator.default.user.watch(anime: anime)
        }
        
        updateNotificationToggle()
    }
    
    private func updateNotificationToggle() {
        guard let anime = anime else {
            notificationToggleButton.isEnabled = false
            return
        }
        notificationToggleButton.isEnabled = true
        
        let image = NineAnimator.default.user.isWatching(anime) ? #imageLiteral(resourceName: "Notification Enabled") : #imageLiteral(resourceName: "Notification Disabled")
        notificationToggleButton.image = image
        
        //Remove the notification once the anime is viewed
        UserNotificationManager.default.clearNotifications(for: anime.link)
    }
}

// MARK: - Initiate playback
extension AnimeViewController {
    private func retriveAndPlay() {
        guard let episodeLink = episodeLink else { return }
        
        episodeRequestTask?.cancel()
        NotificationCenter.default.removeObserver(self)
        
        func clearSelection() {
            tableView.deselectSelectedRow()
            selectedEpisodeCell = nil
        }
        
        episodeRequestTask = anime!.episode(with: episodeLink) {
            [weak self] episode, error in
            guard let self = self else { return }
            guard let episode = episode else { return Log.error(error) }
            self.episode = episode
            
            //Save episode to last playback
            NineAnimator.default.user.entering(episode: episodeLink)
            
            Log.info("Episode target retrived for '%@'", episode.name)
            Log.debug("- Playback target: %@", episode.target)
            
            if episode.nativePlaybackSupported {
                self.episodeRequestTask = episode.retrive {
                    [weak self] media, error in
                    guard let self = self else { return }
                    self.episodeRequestTask = nil
                    
                    guard let media = media else {
                        Log.error("Item not retrived: \"%@\", fallback to web access", error!)
                        DispatchQueue.main.async { [weak self] in
                            let playbackController = SFSafariViewController(url: episode.target)
                            self?.present(playbackController, animated: true, completion: clearSelection)
                        }
                        return
                    }
                    
                    if CastController.default.isReady {
                        CastController.default.initiate(playbackMedia: media, with: episode)
                        DispatchQueue.main.async {
                            RootViewController.shared?.showCastController()
                            clearSelection()
                        }
                    } else {
                        NativePlayerController.default.play(media: media)
                        clearSelection()
                    }
                }
            } else {
                let playbackController = SFSafariViewController(url: episode.target)
                self.present(playbackController, animated: true, completion: clearSelection)
                self.episodeRequestTask = nil
                episode.update(progress: 1.0)
            }
        }
    }
}
