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
    }
    
    deinit {
        if RootViewController.shared == self {
            Log.error("RootViewController is deinitialized.")
        }
    }
}

// MARK: - Exposed APIs
extension RootViewController {
    func presentOnTop(_ vc: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        topViewController.present(vc, animated: animated, completion: completion)
    }
    
    func showCastController() {
        self.castControllerDelegate = CastController.default.present(from: topViewController)
    }
    
    static func open(whenReady link: AnyLink) {
        if let sharedRootViewController = shared {
            sharedRootViewController.open(immedietly: link)
        } else { _pendingOpeningLink = link }
    }
    
    static func restore(whenReady url: URL) {
        if let sharedRootViewController = shared {
            sharedRootViewController._restore(url)
        } else { _pendingRestoreConfig = url }
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

// MARK: - Restore configurations
extension RootViewController {
    static var _pendingRestoreConfig: URL?
    
    fileprivate func _restore(_ config: URL) {
        let alert = UIAlertController(
            title: "Import Configurations",
            message: "How do you want to import this configuration?",
            preferredStyle: .alert
        )
        
        let errorAlert = UIAlertController(
            title: "Error",
            message: "Cannot import configurations",
            preferredStyle: .alert
        )
        
        errorAlert.addAction(UIAlertAction(
            title: "Done",
            style: .cancel,
            handler: nil
        ))
        
        func showErrorAlert() { presentOnTop(errorAlert) }
        
        alert.addAction(UIAlertAction(title: "Replace Current", style: .destructive) {
            _ in
            if !replace(NineAnimator.default.user, with: config) {
                showErrorAlert()
            }
        })
        
        alert.addAction(UIAlertAction(title: "Merge - Pioritize Local", style: .default) {
            _ in
            if !merge(NineAnimator.default.user, with: config, policy: .localFirst) {
                showErrorAlert()
            }
        })
        
        alert.addAction(UIAlertAction(title: "Merge - Pioritize Importing", style: .default) {
            _ in
            if !merge(NineAnimator.default.user, with: config, policy: .remoteFirst) {
                showErrorAlert()
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // Change to Featured view so when we tap back to recents view the imported
        // anime will show up.
        selectedIndex = 0
        presentOnTop(alert)
    }
}

// MARK: - Themable
extension RootViewController {
    func theme(didUpdate theme: Theme) {
        tabBar.barStyle = theme.barStyle
        view.tintColor = theme.tint
    }
}

// MARK: - Display error for downloading task
extension RootViewController {
    @objc func onDownloadingTaskUpdate(_ notification: Notification) {
        guard let content = notification.object as? OfflineContent else { return }
        
        switch content.state {
        case .error(let error):
            let alert = UIAlertController(
                title: "Download Error",
                message: error is NineAnimatorError ? "\(error)" : error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            Log.error("Presenting download error: %@", error)
            DispatchQueue.main.async { [weak self] in self?.presentOnTop(alert) }
        default: break
        }
    }
}
