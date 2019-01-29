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
class AnimeViewController: UITableViewController, AVPlayerViewControllerDelegate, BlendInViewController {
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
    
    @IBOutlet private weak var animeHeadingView: AnimeHeadingView!
    
    @IBOutlet private weak var moreOptionsButton: UIButton!
    
    private var anime: Anime? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let sectionsNeededReloading = Section.indexSet(.all)
                
                if self.anime == nil && oldValue != nil {
                    self.tableView.deleteSections(sectionsNeededReloading, with: .fade)
                }
                
                guard let anime = self.anime else { return }
                
                // Choose a server
                if self.server == nil {
                    if let recentlyUsedServer = NineAnimator.default.user.recentServer,
                        anime.servers[recentlyUsedServer] != nil {
                        self.server = recentlyUsedServer
                    } else {
                        self.server = anime.servers.first!.key
                        Log.info("No server selected. Using %@", anime.servers.first!.key)
                    }
                }
                
                // Update the AnimeLink in the info cell so we get the correct poster displayed
                self.animeLink = anime.link
                
                // Clean user notifications for this anime
                UserNotificationManager.default.clearNotifications(for: anime.link)
                
                // Push server updates to the heading view
                self.animeHeadingView.update(animated: true) { [weak self] in
                    guard let self = self else { return }
                    
                    $0.selectedServerName = anime.servers[self.server!]
                    $0.anime = anime
                    
                    self.tableView.beginUpdates()
                    self.tableView.setNeedsLayout()
                    self.tableView.reloadSections(sectionsNeededReloading, with: .automatic)
                    self.tableView.endUpdates()
                }
                
                // Update history
                NineAnimator.default.user.entering(anime: anime.link)
                NineAnimator.default.user.push()
                
                // Setup userActivity
                self.prepareContinuity()
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
    
    private var selectedEpisodeCell: UITableViewCell?
    
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
        
        // Not updating title anymore because we are showing anime name in the heading view
//        title = link.title
        
        // Fetch anime if anime does not exists
        guard anime == nil else { return }
        
        // Set animeLink property of the heading view so proper anime information is displayed
        animeHeadingView.animeLink = link
        animeHeadingView.sizeToFit()
        view.setNeedsLayout()
        
        animeRequestTask = NineAnimator.default.anime(with: link) {
            [weak self] anime, error in
            guard let anime = anime else {
                Log.error(error)
                self?.presentError(error!) {
                    if !$0 { self?.navigationController?.popViewController(animated: true) }
                }
                return
            }
            self?.anime = anime
            // Initiate playback if episodeLink is set
            if let episodeLink = self?.episodeLink {
                // Present the cast controller if the episode is currently playing on
                // an attached cast device
                if CastController.default.isAttached(to: episodeLink) {
                    CastController.default.presentPlaybackController()
                } else { self?.retriveAndPlay() }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.makeThemable()
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        
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
    func setPresenting(anime link: AnimeLink) {
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
    
    /**
     Initialize the `AnimeViewController` with the link contained
     in the provided `AnyLink`.
     
     - parameters:
        - link: The `AnyLink` object that is used to initialize
                this `AnimeViewController`
     
     `setPresenting(_ link: AnyLink)` is a shortcut for calling
     `setPresenting(episode: EpisodeLink)` or
     `setPresenting(anime: AnimeLink)`.
     */
    func setPresenting(_ link: AnyLink) {
        switch link {
        case .anime(let animeLink): setPresenting(anime: animeLink)
        case .episode(let episodeLink): setPresenting(episode: episodeLink)
        }
    }
}

// MARK: - Table view data source
extension AnimeViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return [Section].all.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .synopsis:
            return anime == nil ? 0 : 1
        case .episodes:
            guard let serverIdentifier = server,
                let episodes = anime?.episodes[serverIdentifier]
                else { return 0 }
            return episodes.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .synopsis:
            let cell = tableView.dequeueReusableCell(withIdentifier: "anime.synopsis", for: indexPath) as! AnimeSynopsisCellTableViewCell
            cell.synopsisText = anime?.description
            cell.stateChangeHandler = {
                [weak tableView] _ in
                tableView?.beginUpdates()
                tableView?.setNeedsLayout()
                tableView?.endUpdates()
            }
            return cell
        case .episodes:
            let episode = episodeLink(for: indexPath)!
            
            // Use detailed view when possible and enabled
            if NineAnimator.default.user.showEpisodeDetails,
                let detailedEpisodeInfo = anime!.episodesAttributes[episode] {
                let cell = tableView.dequeueReusableCell(withIdentifier: "anime.episode.detailed", for: indexPath) as! DetailedEpisodeTableViewCell
                cell.makeThemable()
                cell.episodeInformation = detailedEpisodeInfo
                cell.onStateChange = {
                    [weak self] _ in
                    self?.tableView.beginUpdates()
                    self?.tableView.layoutIfNeeded()
                    self?.tableView.endUpdates()
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "anime.episode", for: indexPath) as! EpisodeTableViewCell
                cell.makeThemable()
                cell.episodeLink = episode
                return cell
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == Section.episodes else {
            tableView.deselectSelectedRow()
            return Log.info("A non-episode cell has been selected")
        }
        
        guard let cell = tableView.cellForRow(at: indexPath), cell != selectedEpisodeCell else {
            Log.info("A cell is either tapped twice or does not exist. Peacefully aborting task.")
            episodeRequestTask?.cancel()
            episodeRequestTask = nil
            selectedEpisodeCell = nil
            tableView.deselectSelectedRow()
            return
        }
        
        guard let episodeLink = episodeLink(for: indexPath) else {
            tableView.deselectSelectedRow()
            return Log.error("Unable to retrive episode link from pool")
        }
        
        selectedEpisodeCell = cell
        self.episodeLink = episodeLink
        
        retriveAndPlay()
    }
    
    func didSelectServer(_ server: Anime.ServerIdentifier) {
        self.server = server
        tableView.reloadSections(Section.indexSet(.episodes), with: .automatic)
        
        NineAnimator.default.user.recentServer = server
        
        // Update headings
        animeHeadingView.update(animated: true) {
            $0.selectedServerName = self.anime!.servers[server]
        }
    }
    
    private func episodeLink(for indexPath: IndexPath) -> EpisodeLink? {
        guard let server = server,
            let episodes = anime?.episodes[server] else {
                return nil
        }
        
        var episode = episodes[indexPath.item]
        
        if NineAnimator.default.user.episodeListingOrder == .reversed {
            episode = episodes[episodes.count - indexPath.item - 1]
        }
        
        return episode
    }
}

// MARK: - Share/Select Server/Notifications
extension AnimeViewController {
    @IBAction private func onSubscribeButtonTapped(_ sender: Any) {
        // Request permission first
        UserNotificationManager.default.requestNotificationPermissions()
        
        // Then update the heading view
        animeHeadingView.update(animated: true) {
            [weak self] _ in
            if let anime = self?.anime {
                NineAnimator.default.user.watch(anime: anime)
            } else if let animeLink = self?.animeLink {
                NineAnimator.default.user.watch(uncached: animeLink)
            }
        }
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
            guard let episode = episode else {
                clearSelection()
                self.presentError(error!)
                return Log.error(error)
            }
            self.episode = episode
            
            //Save episode to last playback
            NineAnimator.default.user.entering(episode: episodeLink)
            
            Log.info("Episode target retrived for '%@'", episode.name)
            Log.debug("- Playback target: %@", episode.target)
            
            if episode.nativePlaybackSupported {
                // Prime the HMHomeManager
                HomeController.shared.primeIfNeeded()
                
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

// Show more options
extension AnimeViewController {
    @IBAction private func onMoreOptionsButtonTapped(_ sender: Any) {
        guard let animeLink = animeLink else { return }
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = moreOptionsButton
        }
        
        actionSheet.addAction({
            let action = UIAlertAction(title: "Select Server", style: .default) {
                [weak self] _ in self?.showSelectServerDialog()
            }
            action.image = #imageLiteral(resourceName: "Server")
            action.textAlignment = .left
            return action
        }())
        
        actionSheet.addAction({
            let action = UIAlertAction(title: "Share", style: .default) {
                [weak self] _ in self?.showShareDiaglog()
            }
            action.image = #imageLiteral(resourceName: "Action")
            action.textAlignment = .left
            return action
        }())
        
        actionSheet.addAction({
            let action = UIAlertAction(title: "Setup Google Cast", style: .default) {
                _ in CastController.default.presentPlaybackController()
            }
            action.image = #imageLiteral(resourceName: "Chromecast Icon")
            action.textAlignment = .left
            return action
        }())
        
        if NineAnimator.default.user.isWatching(anime: animeLink) {
            actionSheet.addAction({
                let action = UIAlertAction(title: "Unsubscribe", style: .default) {
                    [weak self] _ in
                    self?.animeHeadingView.update(animated: true) {
                        _ in NineAnimator.default.user.unwatch(anime: animeLink)
                    }
                }
                action.image = #imageLiteral(resourceName: "Notification Disabled")
                action.textAlignment = .left
                return action
            }())
        }
        
        actionSheet.addAction({
            let action = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
//            action.textAlignment = .left
            return action
        }())
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    private func showSelectServerDialog() {
        let alertView = UIAlertController(title: "Select Server", message: nil, preferredStyle: .actionSheet)
        
        if let popover = alertView.popoverPresentationController {
            popover.sourceView = moreOptionsButton
        }
        
        for server in anime!.servers {
            let action = UIAlertAction(title: server.value, style: .default) {
                [weak self] _ in self?.didSelectServer(server.key)
            }
            if self.server == server.key {
                action.setValue(true, forKey: "checked")
            }
            alertView.addAction(action)
        }
        
        alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertView, animated: true)
    }
    
    private func showShareDiaglog() {
        guard let link = animeLink else { return }
        let activityViewController = UIActivityViewController(activityItems: [link.link], applicationActivities: nil)
        
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = moreOptionsButton
        }
        
        present(activityViewController, animated: true)
    }
}

// Peek preview actions
extension AnimeViewController {
    override var previewActionItems: [UIPreviewActionItem] {
        guard let animeLink = self.animeLink else { return [] }
        
        let subscriptionAction = NineAnimator.default.user.isWatching(anime: animeLink) ?
                UIPreviewAction(title: "Unsubscribe", style: .default) { _, _ in
                    NineAnimator.default.user.unwatch(anime: animeLink)
                } : UIPreviewAction(title: "Subscribe", style: .default) { [weak self] _, _ in
                    if let anime = self?.anime {
                        NineAnimator.default.user.watch(anime: anime)
                    } else { NineAnimator.default.user.watch(uncached: animeLink) }
                }
        
        return [ subscriptionAction ]
    }
}

// MARK: - Continuity support
extension AnimeViewController {
    private func prepareContinuity() {
        guard let anime = anime else { return }
        userActivity = Continuity.activity(for: anime)
    }
}

// MARK: - Error handling
extension AnimeViewController {
    /// Present error
    ///
    /// - parameter error: The error to present
    /// - parameter completionHandler: Called when the user selected an option.
    ///             `true` if the user wants to proceed.
    ///
    private func presentError(_ error: Error, completionHandler: ((Bool) -> Void)? = nil) {
        if let error = error as? NineAnimatorError {
            switch error {
            // If the error is an authentication error with authentication url, try access the url
            case let .authenticationRequiredError(message, authenticationURL):
                guard let authenticationURL = authenticationURL else { break }
                
                let authenticationAlert = UIAlertController(title: "Authentication Required", message: message, preferredStyle: .alert)
                
                authenticationAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel) {
                    _ in completionHandler?(false)
                })
                
                authenticationAlert.addAction(UIAlertAction(title: "Open", style: .default) {
                    [weak self] _ in
                    let authenticationController = SFSafariViewController(url: authenticationURL)
                    self?.present(authenticationController, animated: true) {
                        // Call completion handler with true
                        completionHandler?(true)
                    }
                })
                
                return
            default: break
            }
        }
        
        let alert = UIAlertController(title: "Error", message: String(describing: error), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        present(alert, animated: true) { completionHandler?(false) }
    }
}

// MARK: - Helpers and stubs
fileprivate extension AnimeViewController {
    // Using this enum to remind me to implement stuff when adding new sections...
    fileprivate enum Section: Int, Equatable {
        case synopsis = 0
        
        case episodes = 1
        
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

fileprivate extension Array where Element == AnimeViewController.Section {
    fileprivate static let all: [AnimeViewController.Section] = [ .synopsis, .episodes ]
}
