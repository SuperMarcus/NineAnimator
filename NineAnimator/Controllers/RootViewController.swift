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

import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources
import UIKit

class RootViewController: UITabBarController, Themable {
    private(set) static weak var shared: RootViewController?
    
    private weak var castControllerDelegate: AnyObject?
    
    private var topViewController: UIViewController {
        var topViewController: UIViewController = self
        while let next = topViewController.presentedViewController {
            topViewController = next
        }
        return topViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Update appearance at launch
        updateDynamicTheme()
        
        RootViewController.shared = self
        Theme.provision(self)
        
        // Add observer for downloading task update
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onDownloadingTaskUpdate(_:)),
            name: .offlineAccessStateDidUpdate,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Open the pending if there is any
        if let pendingOpeningLink = RootViewController._pendingOpeningLink {
            RootViewController._pendingOpeningLink = nil
            open(immedietly: pendingOpeningLink)
        }
        
        // Restore config if there is any
        if let pendingRestoreConfig = RootViewController._pendingRestoreConfig {
            RootViewController._pendingRestoreConfig = nil
            _restore(pendingRestoreConfig)
        }
        
        // Open the pending navigating to page
        if let pendingNavigatingTo = RootViewController._pendingNavigatingToPage {
            RootViewController._pendingNavigatingToPage = nil
            navigate(toScene: pendingNavigatingTo)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Show setup wizard
        if !NineAnimator.runtime.isSetupSceneDisabled && !NineAnimator.default.user.didSetupLatestVersion {
            let storyboard = UIStoryboard(name: "Setup", bundle: Bundle.main)
            if let viewController = storyboard.instantiateInitialViewController() {
                viewController.modalPresentationStyle = .fullScreen
                presentOnTop(viewController)
            }
        }
    }
    
    deinit {
        if RootViewController.shared == self {
            Log.error("RootViewController is deinitialized.")
        }
    }
}

// MARK: - Exposed APIs
extension RootViewController {
    /// Presnet the view controller from the topmost view controller
    ///
    /// - Note: If the view controller specified is already presenting, this method calls the completion handler directly.
    func presentOnTop(_ vc: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        let topVc = topViewController
        if topVc != vc {
            topVc.present(vc, animated: animated, completion: completion)
        } else { completion?() }
    }
    
    func showCastController() {
        self.castControllerDelegate = CastController.default.present(from: topViewController)
    }
    
    /// Present the activity sheet for sharing the `AnyLink`
    func presentShareSheet(forLink link: AnyLink, from sourceView: UIView, inViewController vc: UIViewController? = nil) {
        // Sharing the redirection link from NineAnimatorCloud
        let sharingLink = link.cloudRedirectionUrl
        presentShareSheet(forURL: sharingLink, from: sourceView, inViewController: vc)
    }
    
    func presentShareSheet(forURL sharingLink: URL, from sourceView: UIView, inViewController vc: UIViewController? = nil) {
        let activityViewController = UIActivityViewController(
            activityItems: [ sharingLink ],
            applicationActivities: nil
        )
        
        // Configure appearance for iOS 13+
        if #available(iOS 13.0, *) {
            activityViewController.overrideUserInterfaceStyle = overrideUserInterfaceStyle
        }
        
        // Set Source view
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        
        // Present the activity controller
        if let vc = vc {
            vc.present(activityViewController, animated: true)
        } else { presentOnTop(activityViewController) }
    }
    
    /// Open an `AnyLink` struct
    static func open(whenReady link: AnyLink) {
        if let sharedRootViewController = shared {
            sharedRootViewController.open(immedietly: link)
        } else { _pendingOpeningLink = link }
    }
    
    /// Attempt to restore the configuration file located at `url`
    static func restore(whenReady url: URL) {
        if let sharedRootViewController = shared {
            sharedRootViewController._restore(url)
        } else { _pendingRestoreConfig = url }
    }
    
    /// Request the `RootViewController` to navigate to a certain tab/scene
    static func navigateWhenReady(toScene scene: NineAnimatorRootScene) {
        if let shared = RootViewController.shared {
            shared.navigate(toScene: scene)
        } else { _pendingNavigatingToPage = scene }
    }
}

// MARK: - Open links
extension RootViewController {
    fileprivate static var _pendingOpeningLink: AnyLink?
    
    func open(immedietly link: AnyLink, in viewController: UIViewController? = nil) {
        let targetViewController: UIViewController
        
        // Determine if the link is supported
        switch link {
        case .anime, .episode: // Present anime and episode link with AnimeViewController
            let storyboard = UIStoryboard(name: "AnimePlayer", bundle: Bundle.main)
            
            // Instantiate the view controller from storyboard
            guard let animeViewController = storyboard.instantiateInitialViewController() as? AnimeViewController else {
                Log.error("The view controller instantiated from AnimePlayer.storyboard is not AnimeViewController.")
                return
            }
            
            // Initialize the AnimeViewController with the link
            animeViewController.setPresenting(link)
            targetViewController = animeViewController
        case .listingReference:
            let storyboard = UIStoryboard(name: "AnimeInformation", bundle: Bundle.main)
            
            // Instantiate the view controller from storyboard
            guard let animeInformationController = storyboard.instantiateInitialViewController() as? AnimeInformationTableViewController else {
                Log.error("The view controller instantiated from AnimeInformation.storyboard is not AnimeInformationTableViewController.")
                return
            }
            
            // Initialize the AnimeInformationTableViewController with the link
            animeInformationController.setPresenting(link)
            targetViewController = animeInformationController
        }
        
        // If a view controller is provided
        if let viewController = viewController {
            // If the provided view controller has a navigation controller,
            // open the link in the navigation controller. Else present it
            // directly from the provided view controller.
            if let navigationController = viewController.navigationController {
                navigationController.pushViewController(targetViewController, animated: true)
            } else { viewController.present(targetViewController, animated: true) }
        } else { // If no view controller is provided, present the link in the featured tab
            // Jump to Featured tab
            selectedIndex = 0
            
            guard let navigationController = viewControllers?.first as? ApplicationNavigationController else {
                Log.error("The first view controller is not ApplicationNavigationController.")
                return
            }
            
            // Pop to root view controller
            navigationController.popToRootViewController(animated: true)
            navigationController.pushViewController(targetViewController, animated: true)
        }
    }
}

// MARK: - Navigating to Pages
extension RootViewController {
    fileprivate static var _pendingNavigatingToPage: NineAnimatorRootScene?
    
    private func navigate(toScene scene: NineAnimatorRootScene) {
        self.selectedIndex = scene.rawValue
    }
    
    /// Declaration of the available scenes in the `RootViewController`
    enum NineAnimatorRootScene: Int {
        case toWatch = 0
        case featured = 1
        case library = 2
        case search = 3
    }
}

// MARK: - Restore configurations
extension RootViewController {
    static var _pendingRestoreConfig: URL?
    
    fileprivate func _restore(_ config: URL) {
        let alert = UIAlertController(
            title: "Import Configurations",
            message: "How do you want to import this configuration?",
            preferredStyle: .alert
        )
        
        func showErrorAlert(error: Error) {
            Log.error(error)
            let errorAlert = UIAlertController(
                error: error,
                customTitle: "Cannot Import Backup"
            )
            presentOnTop(errorAlert)
        }
        
        alert.addAction(UIAlertAction(title: "Replace Current", style: .destructive) {
            _ in
            do {
                try replace(NineAnimator.default.user, with: config)
            } catch {
                showErrorAlert(error: error)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Merge - Prioritize Local", style: .default) {
            _ in
            do {
                try merge(NineAnimator.default.user, with: config, policy: .localFirst)
            } catch {
                showErrorAlert(error: error)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Merge - Prioritize Importing", style: .default) {
            _ in
            do {
                try merge(NineAnimator.default.user, with: config, policy: .remoteFirst)
            } catch {
                showErrorAlert(error: error)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // Change to Featured view so when we tap back to recents view the imported
        // anime will show up.
        navigate(toScene: .featured)
        presentOnTop(alert)
    }
}

// MARK: - Themable and Theming
extension RootViewController {
    func theme(didUpdate theme: Theme) {
        tabBar.barStyle = theme.barStyle
        tabBar.tintColor = theme.tint
        view.tintColor = theme.tint
        
        // Configure the proper overriding style for the tab bar
        configureStyleOverride(tabBar, withTheme: theme)
    }
    
    /// For dynamic appearances on iOS 13 or later, which syncs with
    /// the system appearance
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        AppDelegate.shared?.updateDynamicAppearance(withTraitCollection: traitCollection)
    }
    
    /// Force update the dynamic theme settings
    func updateDynamicTheme() {
        AppDelegate.shared?.updateDynamicAppearance(withTraitCollection: traitCollection)
    }
}

// MARK: - Display error for downloading task
extension RootViewController {
    @objc func onDownloadingTaskUpdate(_ notification: Notification) {
        guard AppDelegate.shared?.isActive == true,
            let content = notification.object as? OfflineContent else { return }
        
        switch content.state {
        case .error(let error):
            Log.error("Presenting download error: %@", error)
            let alert = UIAlertController(
                error: error,
                customTitle: "Download Error",
                allowRetry: true
            ) { retry in
                if retry {
                    OfflineContentManager
                        .shared
                        .initiatePreservation(content: content)
                }
            }
            DispatchQueue.main.async { [weak self] in self?.presentOnTop(alert) }
        default: break
        }
    }
}
