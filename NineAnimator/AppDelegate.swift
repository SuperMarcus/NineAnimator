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
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    static weak var shared: AppDelegate?
    
    private var shortcutItem: UIApplicationShortcutItem?
    
    var window: UIWindow?
    
    var trackedPasteboardChangeTimes: Int = 0
    
    /// A flag to represent if the app is currently active
    var isActive = false
    
    /// Number of objects that has requested to disable the screen idle timer
    private(set) var screenOnRequestCount = 0
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Shared AppDelegate reference
        AppDelegate.shared = self
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Fetch for generating episode update notifications once in two hours
        UIApplication.shared.setMinimumBackgroundFetchInterval(
            UserNotificationManager.default.suggestedFetchInterval
        )
        
        // Update UserNotification delegate
        UNUserNotificationCenter.current().delegate = UserNotificationManager.default
        
        // Add observer for the dynamic screen brightness feature
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onScreenBrightnessDidChange(_:)),
            name: UIScreen.brightnessDidChangeNotification,
            object: nil
        )
        
        // Store the booting shortcut item
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            self.shortcutItem = shortcutItem
        }
        
        // Recover any pending download tasks
        OfflineContentManager.shared.recoverPendingTasks()
        
        // Setup Kingfisher
        setupImageCacher()
        
        return true
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        // The refernece implementation didn't say to call the completionHandler,
        // so leaving it out for now.
        self.shortcutItem = shortcutItem
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if url.pathExtension == "naconfig" {
            RootViewController.restore(whenReady: url)
            return true
        }
        
        guard let scheme = url.scheme else { return false }
        
        switch scheme {
        case "nineanimator":
            guard let resourceSpecifier = (url as NSURL).resourceSpecifier?.dropFirst(2) else {
                Log.error("Cannot open url '%@': no resource specifier", url.absoluteString)
                return false
            }
            
            let animeUrlString = resourceSpecifier.hasPrefix("http") ? String(resourceSpecifier) : "https://\(resourceSpecifier)"
            
            guard let animeUrl = URL(string: animeUrlString) else {
                Log.error("Cannot open url '%@': invalid url", url.absoluteString)
                return false
            }
            
            let task = NineAnimator.default.link(with: animeUrl) {
                link, error in DispatchQueue.main.async {
                    guard let link = link else {
                        let alert = UIAlertController(
                            title: "Cannot open link",
                            message: error != nil ? "\(error!)" : "Unknown Error",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
                        RootViewController.shared?.presentOnTop(alert)
                        return Log.error(error)
                    }
                    
                    // Open the link when ready
                    RootViewController.open(whenReady: link)
                }
            }
            taskPool = [task]
            
            return true
        default: return false
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // swiftlint:disable implicitly_unwrapped_optional
        var identifier: UIBackgroundTaskIdentifier!
        backgroundTaskContainer = StatefulAsyncTaskContainer {
            state in
            Log.info("[AppDelegate] Background task ended with state %@", state)
            UIApplication.shared.endBackgroundTask(identifier)
        }
        
        identifier = UIApplication.shared.beginBackgroundTask {
            Log.info("[AppDelegate] Background task %@ will expire. Cancelling all running tasks...", identifier.rawValue)
            self.backgroundTaskContainer?.cancel()
            self.backgroundTaskContainer = nil
            UIApplication.shared.endBackgroundTask(identifier)
        }
        
        Log.info("[AppDelegate] Beginning background tasks with identifier %@...", identifier.rawValue)
        
        // Perform fetch when app enters background
        UserNotificationManager.default.performFetch(within: backgroundTaskContainer!)
        
        // Update quick actions
        updateHomescreenQuickActions(application)
        
        // Mark the task container as ready for collection
        backgroundTaskContainer?.collect()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Update isActive flag
        isActive = true
        
        // Check the pasteboard when moved to the application
        if NineAnimator.default.user.detectsPasteboardLinks { fetchUrlFromPasteboard() }
        
        // If a shortcut item has been invoked
        if let shortcutItem = shortcutItem {
            Log.info("[AppDelegate] Performing Homescreen Shortcut %@", shortcutItem.type)
            self.shortcutItem = nil // Remove the stored quick action
            self.performQuickAction(shortcutItem)
        }
        
        // Also updates dynamic appearance
        updateDynamicBrightness()
        
        // Continue download tasks
        OfflineContentManager.shared.preserveContentIfNeeded()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Mark the app as inactive
        isActive = false
        
        // Update quick actions
        updateHomescreenQuickActions(application)
    }
    
    var taskPool: [NineAnimatorAsyncTask?]?
    var backgroundTaskContainer: StatefulAsyncTaskContainer?
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.info("[AppDelegate] Beginning background fetching activities...")
        
        backgroundTaskContainer = StatefulAsyncTaskContainer {
            let finishedState = $0.state
            Log.error("[AppDelegate] Background fetching activities completed (%@)", finishedState)
            switch finishedState {
            case .failed: completionHandler(.failed)
            case .succeeded: completionHandler(.newData)
            case .unknown: completionHandler(.noData)
            }
        }
        
        UserNotificationManager.default.performFetch(within: backgroundTaskContainer!)
        
        // Mark as ready for collection
        backgroundTaskContainer?.collect()
    }
}

// Open links from pasteboard
extension AppDelegate {
    func fetchUrlFromPasteboard() {
        let pasteboard = UIPasteboard.general
        
        if pasteboard.changeCount != trackedPasteboardChangeTimes {
            trackedPasteboardChangeTimes = pasteboard.changeCount
            
            var pasteboardUrl: URL?
            
            if pasteboard.hasStrings {
                let pasteboardContent = pasteboard.string!
                if let urlFromString = URL(string: pasteboardContent) {
                    pasteboardUrl = urlFromString
                }
            }
            
            if pasteboard.hasURLs {
                pasteboardUrl = pasteboard.url
            }
            
            if let url = pasteboardUrl,
                NineAnimator.default.canHandle(link: url) {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Open Link", message: "Do you want to open link: \(url.absoluteString)?", preferredStyle: .alert)
                    
                    let yesOption = UIAlertAction(title: "Yes", style: .default) {
                        [weak self] _ in
                        guard let self = self else { return }
                        let task = NineAnimator.default.link(with: url) {
                            link, error in
                            DispatchQueue.main.async {
                                guard let link = link else {
                                    let alert = UIAlertController(
                                        title: "Cannot open link",
                                        message: error != nil ? "\(error!)" : "Unknown Error",
                                        preferredStyle: .alert
                                    )
                                    alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
                                    RootViewController.shared?.presentOnTop(alert)
                                    return Log.error(error)
                                }
                                
                                // Open the link
                                RootViewController.open(whenReady: link)
                            }
                        }
                        self.taskPool = [task]
                    }
                    
                    let noOption = UIAlertAction(title: "No", style: .cancel, handler: nil)
                    
                    alert.addAction(yesOption)
                    alert.addAction(noOption)
                    
                    RootViewController.shared?.presentOnTop(alert)
                }
            }
        }
    }
}

// MARK: - Continuity
extension AppDelegate {
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
        ) -> Bool {
        switch userActivity.activityType {
        case Continuity.activityTypeViewAnime: // Browse anime
            guard let info = userActivity.userInfo, let linkData = info["link"] as? Data,
                let link = try? PropertyListDecoder().decode(AnimeLink.self, from: linkData) else {
                Log.error("Cannot resume activity: invalid user info")
                return false
            }
            RootViewController.open(whenReady: .anime(link))
        case Continuity.activityTypeResumePlayback: // Resume last watched episode
            guard let episodeLink = NineAnimator.default.user.lastEpisode else {
                Log.info("Will not resume anime playback because no last watched anime record was found.")
                return false
            }
            RootViewController.open(whenReady: .episode(episodeLink))
        case Continuity.activityTypeContinueEpisode: // Handoff episode progress
            guard let info = userActivity.userInfo, let linkData = info["link"] as? Data,
                let progress = info["progress"] as? Float,
                let link = try? PropertyListDecoder().decode(EpisodeLink.self, from: linkData) else {
                Log.error("Cannot resume activity: invalid user info")
                return false
            }
            // Save progress so it will resume once we starts it
            NineAnimator.default.user.update(progress: progress, for: link)
            RootViewController.open(whenReady: .episode(link))
        default: Log.error("Trying to restore unkown activity type %@. Aborting.", userActivity.activityType)
        }
        
        return false
    }
}

// MARK: - Dynamic appearance
extension AppDelegate {
    func updateDynamicBrightness(forceUpdate: Bool = false) {
        guard NineAnimator.default.user.dynamicAppearance else { return }
        
        if #available(iOS 13.0, *) {
            // Not doing anything since dynamic theme
            // synchronizes the theme with the system
            // on iOS 13 or later
            return
        }
        
        let threshold: CGFloat = 0.25
        
        var targetTheme: Theme
        
        if UIScreen.main.brightness > threshold {
            guard let lightTheme = Theme.availableThemes["light"] else { return }
            targetTheme = lightTheme
        } else {
            guard let darkTheme = Theme.availableThemes["dark"] else { return }
            targetTheme = darkTheme
        }
        
        if forceUpdate || Theme.current != targetTheme { Theme.setTheme(targetTheme) }
    }
    
    @objc func onScreenBrightnessDidChange(_ notification: Notification) {
        updateDynamicBrightness()
    }
    
    /// Update the appearance based on system trait collection
    ///
    /// Only works for iOS 13.0 or later. This method does nothing
    /// for piror systems
    ///
    /// This method is called by `RootViewController.traitCollectionDidChange`
    func updateDynamicAppearance(withTraitCollection traits: UITraitCollection) {
        guard NineAnimator.default.user.dynamicAppearance else {
            return Theme.forceUpdate(animated: false)
        }
        
        if #available(iOS 13.0, *) {
            switch traits.userInterfaceStyle {
            case .dark:
                if let theme = Theme.availableThemes["dark"] {
                    Theme.setTheme(theme, animated: true)
                }
            default:
                if let theme = Theme.availableThemes["light"] {
                    Theme.setTheme(theme, animated: true)
                }
            }
        }
    }
}

// MARK: - Initialization & Setups
fileprivate extension AppDelegate {
    /// Initialize Kingfisher
    func setupImageCacher() {
        // Set loading failure image
        Kingfisher.KingfisherManager.shared.defaultOptions.append(.onFailureImage(#imageLiteral(resourceName: "Artwork Load Failure")))
    }
}

// MARK: - Quick Actions
fileprivate extension AppDelegate {
    /// Update the dynamic home actions
    func updateHomescreenQuickActions(_ application: UIApplication) {
        var availableShortcutItems = [UIApplicationShortcutItem]()
        
        // Common Quick Actions
        availableShortcutItems.append(.init(
            type: AppShortcutType.library.rawValue,
            localizedTitle: "Library",
            localizedSubtitle: nil,
            icon: .init(templateImageName: "Library Icon"),
            userInfo: nil
        ))
        
        availableShortcutItems.append(.init(
            type: AppShortcutType.search.rawValue,
            localizedTitle: "Search",
            localizedSubtitle: nil,
            icon: .init(type: .search),
            userInfo: nil
        ))
        
        if let lastWatchedEpisode = NineAnimator.default.user.lastEpisode {
            availableShortcutItems.append(.init(
                type: AppShortcutType.resumeLastWatched.rawValue,
                localizedTitle: "Resume Episode",
                localizedSubtitle: "\(lastWatchedEpisode.name) - \(lastWatchedEpisode.parent.title)",
                icon: .init(type: .play),
                userInfo: nil
            ))
        }
        
        // Update the shortcut items
        application.shortcutItems = availableShortcutItems
    }
    
    /// Perform the quick action
    func performQuickAction(_ shortcutItem: UIApplicationShortcutItem) {
        guard let shortcutType = AppShortcutType(rawValue: shortcutItem.type) else {
            return
        }
        
        switch shortcutType {
        case .library:
            // Navigate to the library scene
            RootViewController.navigateWhenReady(toScene: .library)
        case .search:
            // Search scene
            RootViewController.navigateWhenReady(toScene: .search)
        case .resumeLastWatched:
            // Resume the last watched episode
            if let episodeLink = NineAnimator.default.user.lastEpisode {
                RootViewController.open(whenReady: .episode(episodeLink))
            }
        }
    }
    
    /// Declaration of shortcut types
    enum AppShortcutType: String {
        case library = "com.marcuszhou.nineanimator.shortcut.library"
        case resumeLastWatched = "com.marcuszhou.nineanimator.shortcut.resumeLast"
        case search = "com.marcuszhou.nineanimator.shortcut.search"
    }
}

// MARK: - Screen On Requests
extension AppDelegate {
    /// An object to keep reference to in order to request the device to be kept on
    class ScreenOnRequestHandler {
        private weak var parent: AppDelegate?
        
        fileprivate init(_ parent: AppDelegate) {
            self.parent = parent
        }
        
        deinit { parent?.didLoseReferenceToScreenOnHelper() }
    }
    
    fileprivate func didLoseReferenceToScreenOnHelper() {
        DispatchQueue.main.async {
            self.screenOnRequestCount -= 1
            if self.screenOnRequestCount <= 0 {
                self.screenOnRequestCount = 0
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
    
    /// Request the screen to be kept on
    func requestScreenOn() -> ScreenOnRequestHandler? {
        DispatchQueue.main.async {
            self.screenOnRequestCount += 1
            UIApplication.shared.isIdleTimerDisabled = true
        }
        return ScreenOnRequestHandler(self)
    }
}
