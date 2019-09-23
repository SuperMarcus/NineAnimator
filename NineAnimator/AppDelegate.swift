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
    var window: UIWindow?
    
    var trackedPasteboardChangeTimes: Int = 0
    
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
        
        // Recover any pending download tasks
        OfflineContentManager.shared.recoverPendingTasks()
        
        // Setup Kingfisher
        setupImageCacher()
        
        return true
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
        
        identifier = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(identifier)
        }
        
        // Perform fetch when app enters background
        UserNotificationManager.default.performFetch { _ in
            UIApplication.shared.endBackgroundTask(identifier)
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Check the pasteboard when moved to the application
        if NineAnimator.default.user.detectsPasteboardLinks { fetchUrlFromPasteboard() }
        
        // Also updates dynamic appearance
        updateDynamicBrightness()
    }
    
    var taskPool: [NineAnimatorAsyncTask?]?
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.info("Received background fetch notification.")
        UserNotificationManager.default.performFetch(with: completionHandler)
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

// MARK: - Initialization
extension AppDelegate {
    func setupImageCacher() {
        // Set loading failure image
        Kingfisher.KingfisherManager.shared.defaultOptions.append(.onFailureImage(#imageLiteral(resourceName: "Artwork Load Failure")))
    }
}
