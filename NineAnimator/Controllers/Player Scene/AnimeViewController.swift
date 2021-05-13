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

import AppCenterAnalytics
import AVKit
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources
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
class AnimeViewController: UITableViewController, AVPlayerViewControllerDelegate, BlendInViewController, OfflineAccessButtonDelegate {
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
    
    private var anime: Anime?
    
    var server: Anime.ServerIdentifier? {
        get { anime?.currentServer }
        set {
            guard let server = newValue else { return }
            anime?.select(server: server)
        }
    }
    
    // Set episode will update the server identifier as well
    private var episode: Episode? {
        didSet {
            guard let episode = episode else { return }
            server = episode.link.server
        }
    }
    
    private var contextMenuSelectedEpisode: EpisodeLink?
    
    private var contextMenuSelectedIndexPath: IndexPath?
    
    private var presentedSuggestingEpisode: EpisodeLink?
    
    private var selectedEpisodeCell: UITableViewCell?
    
    private var episodeRequestTask: NineAnimatorAsyncTask?
    
    private var animeRequestTask: NineAnimatorAsyncTask?
    
    private var previousEpisodeRetrivalError: Error?
    
    private var shouldPromptBatchEpisodeMarking = true
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
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
        
        // Load Anime object
        retrieveAnime()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.makeThemable()
        
        // Receive playback did end notification and update suggestions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPlaybackDidEnd(_:)),
            name: .playbackDidEnd,
            object: nil
        )
        
        // Receive batch update playback progress notification and reload episode tableview section
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onBatchPlaybackProgressDidUpdate(_:)),
            name: .batchPlaybackProgressDidUpdate,
            object: nil
        )
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        
        // Cleanup observers and tasks
        episodeRequestTask?.cancel()
        episodeRequestTask = nil
        
        // Remove tableView selections
        tableView.deselectSelectedRows()
        
        // Sets episode and server to nil
        episode = nil
    }
}

// MARK: - Receive & Present Anime
extension AnimeViewController {
    /// Retrieve the Anime object given that the animeLink variable has been set
    ///
    /// This method may be called from another thread
    private func retrieveAnime() {
        // Abort if the link does not exists or the Anime object has already been retrieved
        guard let link = animeLink, anime == nil else { return }
        
        // Store the reference in animeRequestTask
        animeRequestTask = NineAnimator.default.anime(with: link) {
            [weak self] anime, error in
            // Keep track of the usage and error rates of each source
            Analytics.trackEvent("Load Anime", withProperties: [
                "source": link.source.name,
                "success": error == nil ? "YES" : "NO",
                "source_success": "\(link.source.name) - \(error == nil ? "Success" : "Error")"
            ])
            
            guard let anime = anime else {
                guard let error = error else { return }
                Log.error(error)
                
                return DispatchQueue.main.async {
                    // Allow the user to recover the anime by searching in another source
                    if let error = error as? NineAnimatorError.ContentUnavailableError {
                        self?.presentError(error, allowRetry: "Recover") {
                            if $0 {
                                self?.presentRecoveryOptions(for: link, error: error)
                            } else if let navigationController = self?.navigationController {
                                _ = navigationController.popViewController(animated: true)
                            } else { self?.dismiss(animated: true, completion: nil) }
                        }
                        return
                    }
                    
                    self?.presentError(error, allowRetry: "More Options") {
                        // If not allowed to retry, dismiss the view controller
                        guard let self = self else { return }
                        
                        // Retry loading the anime
                        if $0 {
                            if let error = error as? NineAnimatorError.AuthenticationRequiredError,
                                error.authenticationUrl != nil {
                                // That is, if the user completed an authentication
                                self.retrieveAnime()
                            } else {
                                // That is, if the user tapped on the "More Options" buttoon
                                self.presentRecoveryOptions(for: link, error: error)
                            }
                        } else {
                            DispatchQueue.main.async {
                                if let navigationController = self.navigationController {
                                    navigationController.popViewController(animated: true)
                                } else { self.dismiss(animated: true) }
                            }
                        }
                    }
                }
            }
            
            // Asynchronically load the anime in the main thread
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setPresenting(anime: anime)
                // Initiate playback if episodeLink is set
                if let episodeLink = self.episodeLink {
                    // Present the cast controller if the episode is currently playing on
                    // an attached cast device
                    if CastController.default.isAttached(to: episodeLink) {
                        CastController.default.presentPlaybackController()
                    } else { self.retrieveAndPlay() }
                }
            }
        }
    }
    
    /// Called when the Anime is retrieved
    private func setPresenting(anime: Anime) {
        self.anime = anime
        
        let sectionsNeededReloading = Section.indexSet(.all)
        
        // Prepare the tracking context
        anime.prepareForTracking()
        
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

// MARK: - Exposed Interfaces
extension AnimeViewController {
    /**
     Initialize the `AnimeViewController` with the provided
     AnimeLink.
     
     - parameters:
        - link: The `AnimeLink` object that is used to
                initialize this `AnimeViewController`
     
     By calling this method, `AnimeViewController` will use the
     Source object from this link to retrieve the `Anime` object.
     */
    func setPresenting(anime link: AnimeLink) {
        self.episodeLink = nil
        self.animeLink = link
        
        Analytics.trackEvent("Visit Anime", withProperties: [
            "source": link.source.name
        ])
    }
    
    /**
     Initialize the `AnimeViewController` with the parent AnimeLink
     of the provided `EpisodeLink`, and immedietly starts playing
     the episode once the anime is retrived and parsed.
     
     - parameters:
        - episode: The `EpisodeLink` object that is used to
                   initialize this `AnimeViewController`
     
     `AnimeViewController` will first retrieve the Anime object from
     the Source in `AnimeViewController.viewWillAppear`
     */
    func setPresenting(episode link: EpisodeLink) {
        self.episodeLink = link
        
        Analytics.trackEvent("Visit Anime", withProperties: [
            "source": link.parent.source.name
        ])
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
        default: Log.error("Unsupported link: %@", link)
        }
    }
}

// MARK: - Table view data source
extension AnimeViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        [Section].all.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .suggestion, .synopsis:
            return anime == nil ? 0 : 1
        case .episodes:
            return anime?.numberOfEpisodeLinks ?? 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .suggestion:
            let cell = tableView.dequeueReusableCell(withIdentifier: "anime.suggestion", for: indexPath) as! AnimePredictedEpisodeTableViewCell
            updateSuggestingEpisode(for: cell)
            cell.makeThemable()
            return cell
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
                let detailedEpisodeInfo = anime!.attributes(for: episode) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "anime.episode.detailed", for: indexPath) as! DetailedEpisodeTableViewCell
                cell.makeThemable()
                cell.setPresenting(
                    episode,
                    additionalInformation: detailedEpisodeInfo,
                    parent: self
                ) { [weak self] _ in
                    self?.tableView.beginUpdates()
                    self?.tableView.layoutIfNeeded()
                    self?.tableView.endUpdates()
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "anime.episode", for: indexPath) as! EpisodeTableViewCell
                cell.makeThemable()
                cell.setPresenting(episode, parent: self)
                return cell
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == Section.episodes || indexPath.section == Section.suggestion else {
            tableView.deselectSelectedRows()
            return Log.info("A non-episode cell has been selected")
        }
        
        guard let cell = tableView.cellForRow(at: indexPath), cell != selectedEpisodeCell else {
            Log.info("A cell is either tapped twice or does not exist. Peacefully aborting task.")
            episodeRequestTask?.cancel()
            episodeRequestTask = nil
            selectedEpisodeCell = nil
            tableView.deselectSelectedRows()
            return
        }
        
        guard let episodeLink = episodeLink(for: indexPath) else {
            tableView.deselectSelectedRows()
            return Log.error("Unable to retrieve episode link from pool")
        }
        
        // Scroll and highlight the cell in the episodes section
        if cell is AnimePredictedEpisodeTableViewCell,
            let destinationIndexPath = self.indexPath(for: episodeLink) {
            tableView.deselectSelectedRows()
            tableView.selectRow(at: destinationIndexPath, animated: true, scrollPosition: .middle)
        }
        
        selectedEpisodeCell = cell
        self.episodeLink = episodeLink
        
        retrieveAndPlay()
    }
    
    @objc func onBatchPlaybackProgressDidUpdate(_ notification: Notification) {
        Log.info("[AnimeViewController] Batch Playback Progress Notification Received. Reloading TableView Episode Section")
        DispatchQueue.main.async {
            [weak self] in
            guard let self = self else { return }
            self.tableView.performBatchUpdates {
                self.tableView.reloadSections(Section.indexSet(.episodes), with: .fade)
                self.tableView.setNeedsLayout()
            }
        }
    }
}

// MARK: - Initiate playback
extension AnimeViewController {
    /// Retrieve the `Episode` and `PlaybackMedia` and attempt to initiate playback
    private func retrieveAndPlay() {
        // Always uses self.episodeLink since it may be different from the selected cell
        guard let episodeLink = episodeLink else { return }
        
        episodeRequestTask?.cancel()
        NotificationCenter.default.removeObserver(self)
        
        let content = OfflineContentManager.shared.content(for: episodeLink)
        
        let clearSelection = {
            [weak self] in
            DispatchQueue.main.async {
                self?.tableView.deselectSelectedRows()
                self?.selectedEpisodeCell = nil
            }
        }
        
        // Use offline media if google cast is not setup
        if let media = content.media {
            if CastController.default.isReady {
                Log.info("Offline content is available, but Google Cast has been setup. Using online media.")
            } else {
                Log.info("Offline content is available. Using donloaded asset.")
                clearSelection()
                onPlaybackMediaRetrieved(media)
                return
            }
        }
        
        episodeRequestTask = anime!.episode(with: episodeLink) {
            [weak self] episode, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let episode = episode else {
                    if let error = error {
                        // `onEpisodeRetrivalStall` will make sure to unselect cell and release reference to selected cell
                        self.onEpisodeRetrivalStall(error, episodeLink: episodeLink)
                    } else {
                        self.selectedEpisodeCell = nil
                        self.tableView.deselectSelectedRows()
                    }
                    return Log.error(error)
                }
                self.episode = episode
                
                // Save episode to last playback
                NineAnimator.default.user.entering(episode: episodeLink)
                
                Log.info("Episode target retrived for '%@'", episode.name)
                Log.debug("- Playback target: %@", episode.target)
                
                if episode.nativePlaybackSupported {
                    // Prime the HMHomeManager
                    HomeController.shared.primeIfNeeded()
                    
                    self.episodeRequestTask = episode.retrive(
                        forPurpose: CastController.default.isReady
                            ? .googleCast : .playback
                    ) { [weak self] media, error in DispatchQueue.main.async {
                            guard let self = self else { return }
                            
                            defer { clearSelection() }
                            
                            self.episodeRequestTask = nil
                            
                            guard let media = media else {
                                guard let error = error else { return }
                                Log.error("Item not retrived: \"%@\"", error)
                                self.onPlaybackMediaStall(episode.target, error: error)
                                return
                            }
                            
                            // Call media retrieved handler
                            self.onPlaybackMediaRetrieved(media, episode: episode)
                        }
                    }
                } else {
                    // Always stall unsupported episodes and update the progress to 1.0
                    self.onPlaybackMediaStall(
                        episode.target,
                        error: NineAnimatorError.providerError(
                            "NineAnimator does not support playing back from the selected server"
                        )
                    )
                }
            }
        }
    }
    
    /// Handles an episode retrival failiure
    private func onEpisodeRetrivalStall(_ error: Error, episodeLink: EpisodeLink) {
        let restoreInterfaceElements = {
            [weak self] in
            self?.tableView.deselectSelectedRows()
            self?.selectedEpisodeCell = nil
        }
        
        let scrollToSelectedCell = {
            [weak self] in
            guard let self = self else { return }
            if let episodeLink = self.episodeLink,
                let indexPath = self.indexPath(for: episodeLink) {
                self.tableView.selectRow(
                    at: indexPath,
                    animated: true,
                    scrollPosition: .middle
                )
            }
        }
        
        // Let presentError handles the AuthenticationRequiredError
        if error is NineAnimatorError.AuthenticationRequiredError {
            presentError(error)
            return restoreInterfaceElements()
        }
        
        guard let selectedCell = self.selectedEpisodeCell,
            let anime = anime else {
            return restoreInterfaceElements()
        }
        
        // Only present as action sheet if the cell is visible
        let selectedEpisodeIsVisible: Bool
        
        if let visibleIndexPaths = tableView.indexPathsForVisibleRows,
            let episodeIndexPath = indexPath(for: episodeLink),
            visibleIndexPaths.contains(episodeIndexPath) {
            selectedEpisodeIsVisible = true
        } else { selectedEpisodeIsVisible = false }
        
        let alternativeEpisodeLinks: [EpisodeLink]
        var serverMap = anime.servers
        var alertTitle = "Error Retrieving Episode"
        var alertMessage = String.localizedStringWithFormat(
            "Unable to retrieve the episode because of an error: %@ You may want to try one of the following alternatives.",
            error.localizedDescription
        )
        
        // If the error is an EpisodeServerNotAvailableError, then present the list
        // of alternative options
        if let episodeNotOnServerError = error as? NineAnimatorError.EpisodeServerNotAvailableError,
            let alternativeEpisodes = episodeNotOnServerError.alternativeEpisodes {
            // Set updated serverMap
            serverMap = episodeNotOnServerError.updatedServerMap ?? serverMap
            alternativeEpisodeLinks = alternativeEpisodes
            alertTitle = "Alternative Servers"
            alertMessage = "This episode is not available on the selected server. Please choose from one of the following alternatives."
        } else {
            alternativeEpisodeLinks = Array(anime.equivalentEpisodeLinks(of: episodeLink))
        }
        
        // Present the list of alternatives
        let alert = UIAlertController(
            title: alertTitle,
            message: alertMessage,
            preferredStyle: selectedEpisodeIsVisible ? .actionSheet : .alert
        )
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = selectedCell
        }
        
        for alternativeEpisodeLink in alternativeEpisodeLinks {
            alert.addAction(UIAlertAction(
                title: serverMap[
                    alternativeEpisodeLink.server,
                    typedDefault: alternativeEpisodeLink.server
                ],
                style: .default
            ) { [weak self] _ in
                guard let self = self else { return }
                // Update episodeLink and reattempts retrival, without
                // resetting selected items.
                scrollToSelectedCell()
                self.episodeLink = alternativeEpisodeLink
                self.retrieveAndPlay()
            })
        }
        
        // Prompt the user to search in a different source if there are no alternative episodes
        if alternativeEpisodeLinks.isEmpty || previousEpisodeRetrivalError != nil {
            alert.addAction(UIAlertAction(
                title: "Alternative Sources",
                style: .default
            ) { [weak self] _ in
                restoreInterfaceElements()
                ServerSelectionViewController.presentSelectionDialog(from: self) {
                    _ in
                    guard let navigationController = self?.navigationController else {
                        return
                    }
                    navigationController.popViewController(animated: true)
                    
                    // Search in the new source
                    DispatchQueue.main.async {
                        // Preform the search in the current source
                        let searchProvider = NineAnimator.default.user.source.search(
                            keyword: episodeLink.parent.title
                        )
                        let searchVc = ContentListViewController.create(
                            withProvider: searchProvider
                        )
                        
                        // Present the search view controller
                        if let vc = searchVc {
                            navigationController.pushViewController(vc, animated: true)
                        }
                    }
                }
            })
        }
        
        alert.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel
        ) { _ in restoreInterfaceElements() })
        
        previousEpisodeRetrivalError = error
        present(alert, animated: true)
    }
    
    /// Handle when the link to the episode has been retrieved but no streamable link was found
    private func onPlaybackMediaStall(_ fallbackURL: URL, error: Error) {
        Log.info("[PlayerViewController] Playback media retrival stalled with error: %@", error)
        
        if NineAnimator.default.user.playbackFallbackToBrowser {
            // Cleanup selections
            self.tableView.deselectSelectedRows()
            self.selectedEpisodeCell = nil
            let playbackController = SFSafariViewController(url: fallbackURL)
            present(playbackController, animated: true)
        } else if let episodeLink = episodeLink {
            // Let onEpisodeRetrivalStall prompt the user for alternative options
            onEpisodeRetrivalStall(error, episodeLink: episodeLink)
        }
    }
    
    /// Handle the playback media
    private func onPlaybackMediaRetrieved(_ media: PlaybackMedia, episode: Episode? = nil) {
        // Clear previous episode error
        defer { previousEpisodeRetrivalError = nil }
        
        // Use Google Cast if it is setup and ready
        if let episode = episode, CastController.default.isReady {
            CastController.default.initiate(playbackMedia: media, with: episode)
            CastController.default.presentPlaybackController()
        } else { NativePlayerController.default.play(media: media) }
    }
    
    /// Cancels the episode retrival task
    /// - Important: This method must be called from the main thread
    private func cancelEpisodeRetrival() {
        episodeRequestTask?.cancel()
        episodeRequestTask = nil
        tableView.deselectSelectedRows()
    }
}

// MARK: - Suggesting To Watch episode
extension AnimeViewController {
    @IBAction private func onQuickJumpButtonTapped(_ sender: UIButton) {
        guard let server = server, let episodes = anime?.episodes[server] else { return }
        
        // Scroll to the suggested episode if no more than 50 episodes are available
        guard episodes.count > 50 else {
            if let suggestedEpisode = presentedSuggestingEpisode,
                let index = indexPath(for: suggestedEpisode) {
                tableView.scrollToRow(at: index, at: .middle, animated: true)
            }
            return
        }
        
        let quickJumpSheet = UIAlertController(title: "Quick Jump", message: nil, preferredStyle: .actionSheet)
        
        if let popoverController = quickJumpSheet.popoverPresentationController {
            popoverController.sourceView = sender
        }
        
        if episodes.count <= 100 {
            quickJumpSheet.addAction({
                let index = indexPath(for: episodes[0])!
                return UIAlertAction(title: "1 - 49", style: .default) {
                    [weak self] _ in self?.tableView.scrollToRow(at: index, at: .middle, animated: true)
                }
            }())
            
            quickJumpSheet.addAction({
                let index = indexPath(for: episodes[49])!
                return UIAlertAction(title: "50 - \(episodes.count)", style: .default) {
                    [weak self] _ in self?.tableView.scrollToRow(at: index, at: .middle, animated: true)
                }
            }())
        } else {
            let episodesPerSection = 100
            let totalEpisodes = episodes.count
            let totalSections = totalEpisodes / episodesPerSection
            (0...totalSections).compactMap {
                section in
                let startEpisodeNumber = episodesPerSection * section
                let endEpisodeNumber = min(startEpisodeNumber + episodesPerSection, episodes.count)
                
                // If the start episode offset is greater than or equal to the
                // number of episodes, return nil
                guard startEpisodeNumber < totalEpisodes else { return nil }
                
                let index = indexPath(for: episodes[startEpisodeNumber])!
                return UIAlertAction(
                    title: startEpisodeNumber == endEpisodeNumber ?
                        "Episode \(startEpisodeNumber + 1)" : "Episode \(startEpisodeNumber + 1) - \(endEpisodeNumber)",
                    style: .default) {
                    [weak self] _ in self?.tableView.scrollToRow(at: index, at: .middle, animated: true)
                }
            }.forEach(quickJumpSheet.addAction)
        }
        
        if let suggestedEpisode = presentedSuggestingEpisode,
            let index = indexPath(for: suggestedEpisode) {
            let suggestedEpisodeLabel: String = {
                if let episodeNumber = anime?.episodesAttributes[suggestedEpisode]?.episodeNumber {
                    return "Episode \(episodeNumber)"
                } else { return "Episode \(suggestedEpisode.name)" }
            }()
            quickJumpSheet.addAction({
                UIAlertAction(
                    title: "Suggested: \(suggestedEpisodeLabel)",
                    style: .default) {
                    [weak self] _ in self?.tableView.scrollToRow(at: index, at: .middle, animated: true)
                }
            }())
        }
        
        quickJumpSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // Cancel the current loading task if there are any
        // This prevents the 'NSGenericException' runtime exception
        cancelEpisodeRetrival()
        
        present(quickJumpSheet, animated: true, completion: nil)
    }
    
    private func updateSuggestingEpisode(for cell: AnimePredictedEpisodeTableViewCell) {
        guard let anime = anime, let server = server else { return }
        // Search from the latest to the earliest
        guard let availableEpisodes = anime.episodes[server] else { return }
        
        DispatchQueue.global().async {
            [weak self] in
            var suggestingEpisodeLink: EpisodeLink?
            
            func update(_ link: EpisodeLink, reason: AnimePredictedEpisodeTableViewCell.SuggestionReason) {
                DispatchQueue.main.async {
                    cell.episodeLink = link
                    cell.reason = reason
                }
            }
            
            if availableEpisodes.count > 1 {
                // The policy for suggestion is:
                // 1. If an episode with a progress of 0.01...0.80 exists, suggest that episode
                // 2. If an episode with a progress greater than 0.80 exists, suggest the next
                //    episode to that eisode if it exists, or the episode itself if there is no
                //    more after that episode
                // 3. Suggest the first episode
                if let unfinishedAnimeIndex = availableEpisodes.lastIndex(where: { $0.playbackProgress > 0.01 }) {
                    let link: EpisodeLink
                    switch availableEpisodes[unfinishedAnimeIndex].playbackProgress {
                    case 0.80... where (unfinishedAnimeIndex + 1) < availableEpisodes.count:
                        link = availableEpisodes[unfinishedAnimeIndex + 1]
                        update(link, reason: .start)
                    case 0.01..<0.80:
                        link = availableEpisodes[unfinishedAnimeIndex]
                        update(link, reason: .continue)
                    default:
                        link = availableEpisodes[unfinishedAnimeIndex]
                        update(link, reason: .start)
                    }
                    suggestingEpisodeLink = link
                } else {
                    let link = availableEpisodes.first!
                    suggestingEpisodeLink = link
                    update(link, reason: .start)
                }
            } else if let link = availableEpisodes.first {
                suggestingEpisodeLink = link
                update(link, reason: link.playbackProgress > 0.01 ? .continue : .start)
            }
            
            // Store the suggested episode link
            self?.presentedSuggestingEpisode = suggestingEpisodeLink
        }
    }
    
    // Update suggestion when playback did end
    @objc private func onPlaybackDidEnd(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
            [weak self] in self?.tableView?.reloadSections(
                Section.indexSet(.suggestion),
                with: .automatic
            )
        }
    }
}

// MARK: - Handling events from the header view
extension AnimeViewController {
    @IBAction private func onSubscribeButtonTapped(_ sender: Any) {
        // Request permission first
        UserNotificationManager.default.requestNotificationPermissions()
        
        // Then update the heading view
        animeHeadingView.update(animated: true) {
            [weak self] _ in
            if let anime = self?.anime {
                NineAnimator.default.user.subscribe(anime: anime)
            } else if let animeLink = self?.animeLink {
                NineAnimator.default.user.subscribe(uncached: animeLink)
            }
        }
    }
    
    @IBAction private func onMoreOptionsButtonTapped(_ sender: Any) {
        guard let animeLink = animeLink else { return }
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = moreOptionsButton
        }
        
        // If an reference is available, show option to present it
        if anime?.trackingContext.availableReferences.filter({ $0.parentService.isCapableOfListingAnimeInformation }).isEmpty == false {
            actionSheet.addAction({
                let action = UIAlertAction(title: "Show Information", style: .default) {
                    [weak self] _ in self?.performSegue(withIdentifier: "anime.information", sender: self)
                }
                action.image = #imageLiteral(resourceName: "Info")
                action.textAlignment = .left
                return action
            }())
        }
        
        // Show the option to change server only if the anime has been loaded
        if anime != nil {
            actionSheet.addAction({
                let action = UIAlertAction(title: "Select Server", style: .default) {
                    [weak self] _ in self?.showSelectServerDialog()
                }
                action.image = #imageLiteral(resourceName: "Server")
                action.textAlignment = .left
                return action
            }())
        }
        
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
        
        if NineAnimator.default.user.isSubscribing(anime: animeLink) {
            actionSheet.addAction({
                let action = UIAlertAction(title: "Unsubscribe", style: .default) {
                    [weak self] _ in
                    self?.animeHeadingView.update(animated: true) {
                        _ in NineAnimator.default.user.unsubscribe(anime: animeLink)
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
        
        // Cancel the current loading task if there are any
        // This prevents the 'NSGenericException' runtime exception
        cancelEpisodeRetrival()
        
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
        
        // Cancel the current loading task if there are any
        // This prevents the 'NSGenericException' runtime exception
        cancelEpisodeRetrival()
        
        present(alertView, animated: true)
    }
    
    private func showShareDiaglog() {
        guard let link = animeLink else { return }
        
        // Cancel the current loading task if there are any
        // This prevents the 'NSGenericException' runtime exception
        cancelEpisodeRetrival()
        
        // Present the share sheet from this view controller
        RootViewController.shared?.presentShareSheet(
            forLink: .anime(link),
            from: moreOptionsButton,
            inViewController: self
        )
    }
    
    // Update the heading view and reload the list of episodes for the server
    private func didSelectServer(_ server: Anime.ServerIdentifier) {
        self.server = server
        
        tableView.reloadSections(
            Section.indexSet(.episodes, .suggestion),
            with: .automatic
        )
        
        NineAnimator.default.user.recentServer = server
        
        // Update headings
        animeHeadingView.update(animated: true) {
            $0.selectedServerName = self.anime!.servers[server]
        }
    }
}

// Peek preview actions
extension AnimeViewController {
    override var previewActionItems: [UIPreviewActionItem] {
        guard let animeLink = self.animeLink else { return [] }
        
        let subscriptionAction = NineAnimator.default.user.isSubscribing(anime: animeLink) ?
                UIPreviewAction(title: "Unsubscribe", style: .default) { _, _ in
                    NineAnimator.default.user.unsubscribe(anime: animeLink)
                } : UIPreviewAction(title: "Subscribe", style: .default) { [weak self] _, _ in
                    if let anime = self?.anime {
                        NineAnimator.default.user.subscribe(anime: anime)
                    } else { NineAnimator.default.user.subscribe(uncached: animeLink) }
                }
        
        return [ subscriptionAction ]
    }
}

// MARK: - Actions for Episodes
extension AnimeViewController {
    @IBAction private func onLongPress(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began {
            // Obtain the touch position, indexPath, and cell
            let targetTouchPosition = recognizer.location(in: tableView)
            guard let targetIndexPath = tableView.indexPathForRow(at: targetTouchPosition),
                let targetCell = tableView.cellForRow(at: targetIndexPath) else { return }
            
            // Obtain the episode link
            var targetEpisodeLink: EpisodeLink?
            
            if let episodeCell = targetCell as? EpisodeTableViewCell {
                targetEpisodeLink = episodeCell.episodeLink
            }
            
            if let episodeCell = targetCell as? DetailedEpisodeTableViewCell {
                targetEpisodeLink = episodeCell.episodeLink
            }
            
            // If all components exist, present the editing menu
            if let targetEpisodeLink = targetEpisodeLink {
                contextMenuSelectedEpisode = targetEpisodeLink
                contextMenuSelectedIndexPath = targetIndexPath
                presentEditingMenu(for: targetEpisodeLink, from: targetCell)
            }
        }
    }
    
    private func presentEditingMenu(for episodeLink: EpisodeLink, from sourceView: UIView) {
        self.becomeFirstResponder()
        
        let targetRect = tableView.convert(sourceView.frame, to: view)
        let editMenu = UIMenuController.shared
        var availableMenuItems = [UIMenuItem]()
        
        switch episodeLink.playbackProgress {
        case 0..<0.05:
            availableMenuItems.append(UIMenuItem(
                title: "Mark as Completed",
                action: #selector(contextMenu(markAsWatched:))
            ))
        case 0.05..<0.8:
            availableMenuItems.append(UIMenuItem(
                title: "Unwatch",
                action: #selector(contextMenu(markAsUnwatched:))
            ))
            availableMenuItems.append(UIMenuItem(
                title: "Finished",
                action: #selector(contextMenu(markAsWatched:))
            ))
        default:
            availableMenuItems.append(UIMenuItem(
                title: "Unwatch",
                action: #selector(contextMenu(markAsUnwatched:))
            ))
        }
        
        // Save the available actions
        editMenu.menuItems = availableMenuItems
        
        if #available(iOS 13.0, *) {
            editMenu.showMenu(from: view, rect: targetRect)
        } else {
            // Fallback on earlier versions
            editMenu.setTargetRect(targetRect, in: view)
            editMenu.setMenuVisible(true, animated: true)
        }
    }
    
    @objc private func contextMenu(markAsWatched sender: UIMenuController) {
        guard let selectedEpisodeLink = self.contextMenuSelectedEpisode,
              let selectedIndexPath = self.contextMenuSelectedIndexPath,
              let selectedEpisodeCell = tableView.cellForRow(at: selectedIndexPath),
              let anime = self.anime else {
            return DispatchQueue.main.async {
                [weak self] in self?.concludeContextMenu()
            }
        }
        
        let markCurrentEpisodeAsComplete: () -> Void = {
            [weak self] in
            anime.trackingContext.update(progress: 1.0, forEpisodeLink: selectedEpisodeLink)
            anime.trackingContext.endWatching(episode: selectedEpisodeLink)
            DispatchQueue.main.async { self?.concludeContextMenu() }
        }
        
        // Skip mark all episodes prompt for this anime
        if !shouldPromptBatchEpisodeMarking {
            return markCurrentEpisodeAsComplete()
        }
        
        // Ask the user if they want to mark previous episodes "Completed" as well
        let alertMessage = UIAlertController(
            title: "Mark Episode As Complete",
            message: "Do you want to mark previous episodes as complete?",
            preferredStyle: .actionSheet
        )
        
        alertMessage.addAction(.init(title: "Only This Episode", style: .default) {
            _ in markCurrentEpisodeAsComplete()
        })
        
        alertMessage.addAction(.init(title: "All Previous Episodes", style: .default) {
            [weak self] _ in
            // Mark all episodeLinks as complete, this is very intensive
            DispatchQueue.global().async {
                // Retrieve currently selected and previous episodeLinks
                if let currentEpisodeLinkIndex = anime.episodeLinks.firstIndex(of: selectedEpisodeLink) {
                    let episodeLinksArraySlice = anime.episodeLinks[0...currentEpisodeLinkIndex]
                    let episodeLinksToUpdate = Array(episodeLinksArraySlice)
                    anime.trackingContext.update(progress: 1.0, forEpisodeLinks: episodeLinksToUpdate)
                    
                    // Only call this method for the current episodeLink, to reduce unnecessary network requests to Anime Listing Services
                    anime.trackingContext.endWatching(episode: selectedEpisodeLink)
                    
                    DispatchQueue.main.async {
                        self?.concludeContextMenu(batchUpdatePerformed: true)
                    }
                }
            }
        })
        
        alertMessage.addAction(.init(title: "Don't Ask Again", style: .default) {
            [weak self] _ in
            self?.shouldPromptBatchEpisodeMarking = false
            markCurrentEpisodeAsComplete()
        })
        
        alertMessage.addAction(.init(title: "Cancel", style: .cancel) {
            [weak self] _ in self?.concludeContextMenu()
        })
        
        alertMessage.popoverPresentationController?.sourceView = selectedEpisodeCell
        alertMessage.popoverPresentationController?.sourceRect = selectedEpisodeCell.bounds
        
        present(alertMessage, animated: true)
    }
    
    @objc private func contextMenu(markAsUnwatched sender: UIMenuController) {
        if let episodeLink = contextMenuSelectedEpisode, let tracker = anime?.trackingContext {
            tracker.update(progress: 0.0, forEpisodeLink: episodeLink)
        }
        DispatchQueue.main.async { self.concludeContextMenu() }
    }
    
    /// Closes context menu and reloads episodeLink's tableViewRow
    /// - Parameters:
    ///     - batchUpdatePerformed: Boolean indicating if more than 1 episode's progress has been updated.
    private func concludeContextMenu(batchUpdatePerformed: Bool = false) {
        /// Do not reload tableView if batch update has occured.
        /// `onBatchPlaybackProgressDidUpdate(:_)` will handle reloading the tableView
        if let targetIndexPath = contextMenuSelectedIndexPath, !batchUpdatePerformed {
            tableView.performBatchUpdates({
                tableView.reloadRows(at: [targetIndexPath], with: .fade)
                tableView.setNeedsLayout()
            }, completion: nil)
        }
        
        contextMenuSelectedIndexPath = nil
        contextMenuSelectedEpisode = nil
    }
    
    func offlineAccessButton(
        shouldProceedWithDownload source: OfflineAccessButton,
        forEpisodeLink episodeLink: EpisodeLink,
        completionHandler: @escaping (Bool, Anime?) -> Void
    ) {
        guard let anime = anime else {
            return completionHandler(false, nil)
        }
        
        // Obtain a list of recommended download source
        let recommendedServers = anime.source.recommendServers(
            for: anime,
            ofPurpose: .download
        )
        
        // Find a list of equivalent episode links on the recommended servers
        // for downloading
        let alternativeEpisodeLinks = recommendedServers.compactMap {
            anime.equivalentEpisodeLinks(of: episodeLink, onServer: $0)
        }
        
        // Check if the selected server is recommended by the source for downloading
        if recommendedServers.contains(episodeLink.server) || NineAnimator.default.user.shouldSilenceUnrecommendedWarnings(
                forServer: episodeLink.server,
                ofPurpose: .download
            ) {
            completionHandler(true, anime)
        } else {
            var alertMessage = "Downloads from \(anime.servers[episodeLink.server] ?? "the current server") may fail or become unplayable after completion. "
            
            if alternativeEpisodeLinks.isEmpty {
                alertMessage += "You may want to consider switching to another anime source."
            } else { alertMessage += "You may want to consider one of the following alternatives." }
            
            let alert = UIAlertController(
                title: "Not Recommended Server",
                message: alertMessage,
                preferredStyle: .actionSheet
            )
            
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = source
            }
            
            // Alternative download options
            alternativeEpisodeLinks.forEach {
                alternativeLink in
                let alternativeServer = alternativeLink.server
                let serverName = anime.servers[alternativeServer] ?? alternativeServer
                
                alert.addAction(UIAlertAction(
                    title: "\(serverName)",
                    style: .default
                ) { [weak self] _ in
                    guard let self = self else { return }
                    
                    // Mark the alternative server as selected
                    self.didSelectServer(alternativeServer)
                    
                    // Initiate download on the selected server
                    OfflineContentManager.shared.initiatePreservation(
                        for: alternativeLink,
                        withLoadedAnime: self.anime
                    )
                })
            }
            
            // Proceed action
            alert.addAction(UIAlertAction(
                title: "Proceed Anyways",
                style: .destructive
            ) { _ in
                // Silence the warnings and proceed with the download
                NineAnimator.default.user.silenceUnrecommendedWarnings(
                    forServer: episodeLink.server,
                    ofPurpose: .download
                )
                completionHandler(true, anime)
            })
            
            // Cancel action
            alert.addAction(UIAlertAction(
                title: "Cancel",
                style: .cancel
            ) { _ in completionHandler(false, nil) })
            
            // Cancel the current loading task if there are any
            // This prevents the 'NSGenericException' runtime exception
            cancelEpisodeRetrival()
            
            present(alert, animated: true)
        }
    }
}

// MARK: - Seguing
extension AnimeViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // If we are presenting a reference
        if let informationViewController = segue.destination as? AnimeInformationTableViewController {
            guard let availableReferences = anime?.trackingContext.availableReferences else { return Log.error("[AnimeViewController] Cannot prepare for a Show Information segue without a capable reference.") }
            
            let selectedReference: ListingAnimeReference
            
            if let preferredService = NineAnimator.default.user.preferredAnimeInformationService,
                let preferredReference = availableReferences.first(where: {
                    $0.parentService.name == preferredService.name
                }) {
                selectedReference = preferredReference
            } else if let firstCapableReference = availableReferences.first(where: {
                $0.parentService.isCapableOfListingAnimeInformation
            }) {
                selectedReference = firstCapableReference
            } else {
                return Log.error(
                    "[AnimeViewController] No reference from list service that supports anime information was found."
                )
            }
            
            // Set reference and mark the parent view controller as matching the anime
            informationViewController.setPresenting(
                reference: selectedReference,
                isPreviousViewControllerMatchingAnime: true
            )
        }
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
    /// - parameter error: The error to present.
    /// - parameter allowRetry: Pass any non-nil String to show an retry option.
    /// - parameter completionHandler: Called when the user selected an option.
    ///             `true` if the user wants to proceed.
    ///
    private func presentError(_ error: Error, allowRetry retryActionName: String? = nil, completionHandler: ((Bool) -> Void)? = nil) {
        let alert = UIAlertController(
            error: error,
            allowRetry: retryActionName != nil,
            retryActionName: retryActionName ?? "Recover",
            source: self,
            completionHandler: completionHandler
        )
        present(alert, animated: true)
    }
    
    /// Present a list of recovery options if the anime is no longer available
    /// from this source
    private func presentRecoveryOptions(for link: AnimeLink, error: Error) {
        // This may only work with the context of an navigation controller
        guard let navigationController = navigationController else {
            return dismiss(animated: true, completion: nil)
        }
        
        // Search the link's title in the currently selected source
        // (for recovery method 2 and 3)
        let presentSearchDialog = {
            // Preform the search in the current source
            let searchProvider = NineAnimator.default.user.source.search(keyword: link.title)
            let searchVc = ContentListViewController.create(withProvider: searchProvider)
            
            // Present the search view controller
            if let vc = searchVc {
                navigationController.pushViewController(vc, animated: true)
            }
        }
        
        // Message to be displayed
        let recoveryMessage: String
        
        switch error {
        case _ as NineAnimatorError.ContentUnavailableError:
            recoveryMessage = "This anime is no longer available on \(link.source.name) from NineAnimator. You may be able to recover the item by access the web page or search in a different source."
        default:
            recoveryMessage = "NineAnimator encountered an error while trying to fetch this content on \(link.source.name). You may be able to access this content on a different source."
        }
        
        let alert = UIAlertController(
            title: "Recovery Options",
            message: recoveryMessage,
            preferredStyle: .actionSheet
        )
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = moreOptionsButton
        }
        
        // Method 1: Accessing the page directly
        alert.addAction(UIAlertAction(
            title: "Visit Website",
            style: .default
        ) { _ in
            // Pop the current view controller
            navigationController.popViewController(animated: true)
            
            // Present the website in the next tick
            DispatchQueue.main.async {
                let pageVc = SFSafariViewController(url: link.link)
                navigationController.topViewController?.present(pageVc, animated: true, completion: nil)
            }
        })
        
        // Method 2: Select a different source
        alert.addAction(UIAlertAction(
            title: "Alternative Sources",
            style: .default
        ) { [weak self] _ in
            guard let self = self else { return }
            ServerSelectionViewController.presentSelectionDialog(from: self) {
                _ in
                // Pop the current view controller
                navigationController.popViewController(animated: true)
                
                // Search in the new source
                DispatchQueue.main.async(execute: presentSearchDialog)
            }
        })
        
        if NineAnimator.default.user.source.name != link.source.name {
            // Method 3: Search on the currently selected source
            alert.addAction(UIAlertAction(
                title: "Search in \(NineAnimator.default.user.source.name)",
                style: .default
            ) { _ in
                // Pop the current view controller
                navigationController.popViewController(animated: true)
                
                // Search in the new source
                DispatchQueue.main.async(execute: presentSearchDialog)
            })
        }
        
        // Cancel action
        alert.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel
        ) { _ in navigationController.popViewController(animated: true) })
        
        // Present recovery actions
        present(alert, animated: true)
    }
}

// MARK: - Helpers and stubs
fileprivate extension AnimeViewController {
    /// Retrive EpisodeLink for the specific indexPath
    private func episodeLink(for indexPath: IndexPath) -> EpisodeLink? {
        guard let episodes = anime?.episodeLinks else {
                return nil
        }
        
        switch Section(rawValue: indexPath.section)! {
        case .episodes:
            let episode: EpisodeLink
            if NineAnimator.default.user.episodeListingOrder == .reversed {
                episode = episodes[episodes.count - indexPath.item - 1]
            } else { episode = episodes[indexPath.item] }
            return episode
        case .suggestion: return presentedSuggestingEpisode
        default: return nil
        }
    }
    
    private func indexPath(for episodeLink: EpisodeLink) -> IndexPath? {
        guard var episodes = anime?.episodeLinks else {
            return nil
        }
        
        if NineAnimator.default.user.episodeListingOrder == .reversed {
            episodes = episodes.reversed()
        }
        
        if let index = episodes.firstIndex(of: episodeLink) {
            return Section.episodes[index]
        }
        
        return nil
    }
    
    // Using this enum to remind me to implement stuff when adding new sections...
    enum Section: Int, Equatable {
        case suggestion = 0
        
        case synopsis = 1
        
        case episodes = 2
        
        subscript(_ item: Int) -> IndexPath {
            IndexPath(item: item, section: self.rawValue)
        }
        
        static func indexSet(_ sections: [Section]) -> IndexSet {
            IndexSet(sections.map { $0.rawValue })
        }
        
        static func indexSet(_ sections: Section...) -> IndexSet {
            IndexSet(sections.map { $0.rawValue })
        }
        
        static func == (_ lhs: Section, _ rhs: Section) -> Bool {
            lhs.rawValue == rhs.rawValue
        }
        
        static func == (_ lhs: Int, _ rhs: Section) -> Bool {
            lhs == rhs.rawValue
        }
        
        static func == (_ lhs: Section, _ rhs: Int) -> Bool {
            lhs.rawValue == rhs
        }
    }
}

fileprivate extension Array where Element == AnimeViewController.Section {
    static let all: [AnimeViewController.Section] = [ .suggestion, .synopsis, .episodes ]
}
