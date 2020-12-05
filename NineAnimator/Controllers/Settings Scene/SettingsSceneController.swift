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
import Kingfisher
import SafariServices
import UIKit
import UserNotifications

// swiftlint:disable cyclomatic_complexity
class SettingsSceneController: UITableViewController, Themable, UIAdaptivePresentationControllerDelegate {
    @IBOutlet private weak var episodeListingOrderControl: UISegmentedControl!
    @IBOutlet private weak var detectClipboardLinksSwitch: UISwitch!
    @IBOutlet private weak var viewingHistoryStatsLabel: UILabel!
    @IBOutlet private weak var backgroundPlaybackSwitch: UISwitch!
    @IBOutlet private weak var pictureInPictureSwitch: UISwitch!
    @IBOutlet private weak var subscriptionStatsLabel: UILabel!
    @IBOutlet private weak var subscriptionStatusLabel: UILabel!
    @IBOutlet private weak var preferredAnimeDetailsSourceLabel: UILabel!
    @IBOutlet private weak var subscriptionShowStreamsSwitch: UISwitch!
    @IBOutlet private weak var appearanceSegmentControl: UISegmentedControl!
    @IBOutlet private weak var dynamicAppearanceSwitchLabel: UILabel!
    @IBOutlet private weak var nsfwSwitchTextLabel: UILabel!
    @IBOutlet private weak var dynamicAppearanceSwitch: UISwitch!
    @IBOutlet private weak var animeShowEpisodeDetailsSwitch: UISwitch!
    @IBOutlet private weak var allowNSFWContentSwitch: UISwitch!
    @IBOutlet private weak var fallbackToBrowserSwitch: UISwitch!
    @IBOutlet private weak var richPresenceStatusLabel: UILabel!
    @IBOutlet private weak var appIconTableViewCell: UITableViewCell!
    @IBOutlet private weak var currentAppIconLabel: UILabel!
    
    /// The path that the Settings view controller will be navigating to
    private var navigatingTo: EntryPath?
    
    /// Dismissal handler
    private var onDismissal: (() -> Void)?
    private var _fTimerCounter = 0 {
        didSet {
            if (_fTimerCounter % 30) == 0 {
                _handleCounterTrigger()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.makeThemable()
        configureForTransparentScrollEdge()
        Theme.provision(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Settings scene controller should be present in its own containing
        // navigation controller
        if let navigationController = navigationController {
            navigationController.presentationController?.delegate = self
        } else { presentationController?.delegate = self }
        
        // Updates the UI based off the saved settings
        updatePreferencesUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Jump to segue
        if let navigatingTo = self.navigatingTo {
            self.navigatingTo = nil
            
            // Perform segue
            if let segue = navigatingTo.segueIdentifier {
                self.performSegue(withIdentifier: segue, sender: self)
            } else if let indexPath = navigatingTo.itemIndex {
                self.tableView.scrollToRow(
                    at: indexPath,
                    at: .middle,
                    animated: true
                )
            }
        }
    }
}

// MARK: - IBActions
extension SettingsSceneController {
    @IBAction private func onDetectClipboardLinksChange(_ sender: UISwitch) {
        NineAnimator.default.user.detectsPasteboardLinks = sender.isOn
    }
    
    @IBAction private func onEpisodeListingOrderChange(_ sender: UISegmentedControl) {
        defer { NineAnimator.default.user.push() }
        
        switch sender.selectedSegmentIndex {
        case 0: NineAnimator.default.user.episodeListingOrder = .reversed
        case 1: NineAnimator.default.user.episodeListingOrder = .ordered
        default: return
        }
    }
    
    @IBAction private func onPiPDidChange(_ sender: UISwitch) {
        let newValue = sender.isOn
        NineAnimator.default.user.allowPictureInPicturePlayback = newValue
        updatePreferencesUI()
    }
    
    @IBAction private func onBackgroundPlaybackDidChange(_ sender: UISwitch) {
        NineAnimator.default.user.allowBackgroundPlayback = sender.isOn
    }
    
    @IBAction private func onPlaybackFallbackToBrowserDidChange(_ sender: UISwitch) {
        NineAnimator.default.user.playbackFallbackToBrowser = sender.isOn
    }
    
    @IBAction private func onShowStreamsInNotificationDidChange(_ sender: UISwitch) {
        NineAnimator.default.user.notificationShowStreams = sender.isOn
    }
    
    @IBAction private func onShowEpisodeDetailsDidChange(_ sender: UISwitch) {
        NineAnimator.default.user.showEpisodeDetails = sender.isOn
    }
    
    @IBAction private func onAllowNSFWDidChange(_ sender: UISwitch) {
        NineAnimator.default.user.allowNSFWContent = sender.isOn
        _fTimerCounter += 1
    }
    
    @IBAction private func onDoneButtonClicked(_ sender: Any) {
        dismiss(animated: true, completion: onDismissal)
        onDismissal = nil
    }
    
    @IBAction private func onAppearanceDidChange(_ sender: UISegmentedControl) {
        let newAppearanceName = sender.selectedSegmentIndex == 0 ? "dark" : "light"
        guard let theme = Theme.availableThemes[newAppearanceName] else { return }
        Theme.setTheme(theme)
    }
    
    @IBAction private func onDynamicAppearanceDidChange(_ sender: UISwitch) {
        // Dynamic appearance is managed by the AppDelegate
        NineAnimator.default.user.dynamicAppearance = sender.isOn
        RootViewController.shared?.updateDynamicTheme() // Sync with the current theme
        updatePreferencesUI()
    }
}

// MARK: - Delegate
extension SettingsSceneController {
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.makeThemable()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectSelectedRows() }
        
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        
        func askForConfirmation(title: String,
                                message: String,
                                continueActionName: String,
                                proceed: @escaping () -> Void) {
            let alertView = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            configureStyleOverride(alertView)
            
            if let popover = alertView.popoverPresentationController {
                popover.sourceView = cell.contentView
                popover.permittedArrowDirections = .any
            }
            
            let action = UIAlertAction(title: continueActionName, style: .destructive) { _ in proceed() }
            alertView.addAction(action)
            
            alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alertView, animated: true)
        }
        
        switch cell.reuseIdentifier {
        case "settings.viewrepo":
            let safariViewController = SFSafariViewController(url: URL(string: "https://github.com/SuperMarcus/NineAnimator")!)
            present(safariViewController, animated: true)
        case "settings.playback.cast.controller":
            RootViewController.shared?.showCastController()
        case "settings.history.recents":
            askForConfirmation(title: "Clear Recent Anime",
                               message: "This action is irreversible. All anime history under Recents will be cleared.",
                               continueActionName: "Clear Recents"
            ) { [weak self] in
                NineAnimator.default.user.clearRecents()
                self?.updatePreferencesUI()
            }
        case "settings.history.cache":
            clearCache()
        case "settings.history.search":
            askForConfirmation(title: "Clear Search History",
                               message: "This action is irreversible. All of your search history will be removed. Your recent anime list will not be affected.",
                               continueActionName: "Clear Search History"
            ) { NineAnimator.default.user.clearSearchHistory() }
        case "settings.history.download":
            askForConfirmation(title: "Remove all Downloads",
                               message: "This action is irreversible. All downloaded episodes and contents will be removed.",
                               continueActionName: "Remove Downloads"
            ) { OfflineContentManager.shared.deleteAll() }
        case "settings.history.reset":
            askForConfirmation(title: "Reset NineAnimator",
                               message: "This action is irreversible. All data and preferences will be deleted from your local storage.",
                               continueActionName: "Reset"
            ) { [weak self] in
                NineAnimator.default.user.clearAll()
                self?.logoutOfAllListingServices()
                self?.clearCache()
                self?.clearActivities()
                self?.updatePreferencesUI()
            }
        case "settings.notification.unsubscribe":
            askForConfirmation(title: "Unsubscribe from All",
                               message: "This action is irreversible. You will be unsubscribed from all anime.",
                               continueActionName: "Unsubscribe All"
            ) { [weak self] in
                NineAnimator.default.user.unsubscribeAll()
                self?.updatePreferencesUI()
            }
        case "settings.history.activities":
            askForConfirmation(title: "Delete All Activity Items",
                               message: "This action is irreversible. All existing Siri Shortcuts and Spotlight items will be deleted.",
                               continueActionName: "Clear Activities"
            ) { [weak self] in self?.clearActivities() }
        case "settings.history.export":
            guard let exportedSettingsUrl = export(NineAnimator.default.user) else {
                let alert = UIAlertController(title: "Error", message: "Cannot export configurations", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                return
            }
            
            let activityController = UIActivityViewController(activityItems: [exportedSettingsUrl], applicationActivities: nil)
            
            if let popoverController = activityController.popoverPresentationController {
                popoverController.sourceView = cell
                popoverController.sourceRect = cell.bounds
            }
            
            present(activityController, animated: true, completion: nil)
        case "settings.history.import":
            if #available(iOS 14.0, *) {
                let documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: [UTType("nineanimator.config")!])
                documentPickerController.delegate = self
                self.present(documentPickerController, animated: true)
            } else {
                // Fallback on earlier versions
                let documentPickerController = UIDocumentPickerViewController(documentTypes: ["nineanimator.config"], in: .open)
                documentPickerController.delegate = self
                self.present(documentPickerController, animated: true)
            }
        default: return
        }
    }
}

// MARK: - Syncing UI Components
extension SettingsSceneController {
    private func updatePreferencesUI() {
        episodeListingOrderControl.selectedSegmentIndex = NineAnimator.default.user.episodeListingOrder == .reversed ? 0 : 1
        animeShowEpisodeDetailsSwitch.setOn(NineAnimator.default.user.showEpisodeDetails, animated: true)
        detectClipboardLinksSwitch.setOn(NineAnimator.default.user.detectsPasteboardLinks, animated: true)
        
        allowNSFWContentSwitch.setOn(NineAnimator.default.user.allowNSFWContent, animated: true)
        
        pictureInPictureSwitch.isEnabled = AVPictureInPictureController.isPictureInPictureSupported()
        pictureInPictureSwitch.setOn(AVPictureInPictureController.isPictureInPictureSupported() && NineAnimator.default.user.allowPictureInPicturePlayback, animated: true)
        
        backgroundPlaybackSwitch.isEnabled = !pictureInPictureSwitch.isOn
        backgroundPlaybackSwitch.setOn(NineAnimator.default.user.allowBackgroundPlayback || (AVPictureInPictureController.isPictureInPictureSupported() && NineAnimator.default.user.allowPictureInPicturePlayback), animated: true)
        
        fallbackToBrowserSwitch.setOn(
            NineAnimator.default.user.playbackFallbackToBrowser,
            animated: true
        )
        
        // Appearance settings
        appearanceSegmentControl.selectedSegmentIndex = Theme.current.name == "dark" ? 0 : 1
        appearanceSegmentControl.isEnabled = !NineAnimator.default.user.dynamicAppearance
        dynamicAppearanceSwitch.setOn(NineAnimator.default.user.dynamicAppearance, animated: true)
        if UIApplication.shared.supportsAlternateIcons {
            currentAppIconLabel.text = UIApplication.shared.alternateIconName ?? "Default"
            appIconTableViewCell.isUserInteractionEnabled = true
        } else {
            currentAppIconLabel.text = "Unavailable"
            appIconTableViewCell.isUserInteractionEnabled = false
        }
        
        if #available(iOS 13.0, *) {
            dynamicAppearanceSwitchLabel.text = "Sync with System"
        } else { dynamicAppearanceSwitchLabel.text = "Dynamic Appearance" }
        
        if _fTimerCounter >= 30 {
            let swText = nsfwSwitchTextLabel.text
            nsfwSwitchTextLabel.text = NineAnimator.default.user.enableExperimentalSources
                ? swText?.uppercased() : swText?.lowercased()
        }
        
        // To be gramatically correct :D
        let recentAnimeCount = NineAnimator.default.user.recentAnimes.count
        viewingHistoryStatsLabel.text = "\(recentAnimeCount) \(recentAnimeCount == 1 ? "Item" : "Items")"
        
        let subscribedAnimeCount = NineAnimator.default.user.subscribedAnimes.count
        subscriptionStatsLabel.text = "\(subscribedAnimeCount) \(subscribedAnimeCount == 1 ? "Item" : "Items")"
        
        subscriptionShowStreamsSwitch.setOn(NineAnimator.default.user.notificationShowStreams, animated: true)
        
        preferredAnimeDetailsSourceLabel.text =
            NineAnimator.default.user.preferredAnimeInformationService?.name
            ?? "Automatic"
        richPresenceStatusLabel.text = SettingsRichPresenceController.currentStatus
        
        // Notification and fetch status
        var subscriptionEngineStatus = [String]()
        
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available: break
        case .denied: subscriptionEngineStatus.append("App Refresh Denied")
        case .restricted: subscriptionEngineStatus.append("App Refresh Restricted")
        @unknown default: Log.info("Background refresh status is unknown to NineAnimator. Maybe the app needs an upgrade?")
        }
        
        UNUserNotificationCenter.current().getNotificationSettings {
            settings in
            if settings.authorizationStatus == .denied {
                subscriptionEngineStatus.append("Permission Denied")
            }
            
            DispatchQueue.main.async {
                [weak self] in
                self?.subscriptionStatusLabel.text = subscriptionEngineStatus.isEmpty ?
                    "Normal" : subscriptionEngineStatus.joined(separator: ", ")
            }
        }
    }
    
    // Register this class as themable to update the segment control value when theme changes
    func theme(didUpdate _: Theme) {
        updatePreferencesUI()
    }
}

// MARK: - Navigations & Segues
extension SettingsSceneController {
    @IBAction private func onUnwindingFromPreferredAnimeDetailsSource(segue: UIStoryboardSegue) {
        updatePreferencesUI()
    }
}

// MARK: - Create settings table view controller
extension SettingsSceneController {
    class func create(navigatingTo: EntryPath? = nil, onDismissal: (() -> Void)? = nil) -> UIViewController? {
        let storyboard = UIStoryboard(name: "Settings", bundle: .main)
        if let viewController = storyboard.instantiateInitialViewController() {
            // Set presentation style to form sheet
            viewController.modalPresentationStyle = .formSheet
            
            // Initialize the preferences scene controller
            if let viewController = viewController as? ApplicationNavigationController,
                let preferencesController = viewController.viewControllers.first as? SettingsSceneController {
                preferencesController.navigatingTo = navigatingTo
                preferencesController.onDismissal = onDismissal
            } else { Log.error("[SettingsSceneController] The first view controller initiated from the storyboard is not an instance of SettingsSceneController.") }
            
            return viewController
        }
        return nil
    }
}

// MARK: - Miscs & Handlers
extension SettingsSceneController {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismissal?()
        onDismissal = nil
    }
    
    private func _handleCounterTrigger() {
        let previousState = NineAnimator.default.user.enableExperimentalSources
        NineAnimator.default.user.enableExperimentalSources = !previousState
        Log.info("[SettingsSceneController] F.Counter triggered. Current state is %@", !previousState)
        Analytics.trackEvent("exp.counter.trigger", withProperties: [
            "state": previousState ? "back to normal" : "xp",
            "counter": _fTimerCounter.description
        ])
        updatePreferencesUI()
    }
    
    private func clearCache() {
        Kingfisher.ImageCache.default.clearDiskCache()
        Kingfisher.ImageCache.default.clearMemoryCache()
        URLCache.shared.removeAllCachedResponses()
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        UserNotificationManager.default.removeAll()
    }
    
    private func clearActivities() {
        if #available(iOS 12.0, *) {
            NSUserActivity.deleteAllSavedUserActivities {
                [weak self] in DispatchQueue.main.async {
                    self?.updatePreferencesUI()
                }
            }
        }
    }
    
    private func logoutOfAllListingServices() {
        NineAnimator.default.trackingServices.forEach {
            trackingService in
            if trackingService.isCapableOfRetrievingAnimeState {
                trackingService.deauthenticate()
            }
        }
    }
}

// MARK: - Navigating to Items
extension SettingsSceneController {
    struct EntryPath {
        /// Navigating to the `About` entry
        static var about: EntryPath {
            EntryPath(segueIdentifier: "about", itemIndex: nil)
        }
        
        /// Navigating to the `Home` entry
        static var home: EntryPath {
            EntryPath(segueIdentifier: "homekit", itemIndex: nil)
        }
        
        /// Navigating to the `Tracking Service` entry
        static var trackingService: EntryPath {
            EntryPath(segueIdentifier: "trackingService", itemIndex: nil)
        }
        
        /// Navigating to the `Storage` entry
        static var storage: EntryPath {
            EntryPath(segueIdentifier: "storage", itemIndex: nil)
        }
        
        /// Navigating to the `App Icon` entry
        static var appIcon: EntryPath {
            EntryPath(segueIdentifier: "appIcon", itemIndex: nil)
        }
        
        fileprivate let segueIdentifier: String?
        fileprivate let itemIndex: IndexPath?
    }
}
