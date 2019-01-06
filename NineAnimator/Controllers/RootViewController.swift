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

class RootViewController: UITabBarController {
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Open the pending if there is any
        if let pendingOpeningLink = RootViewController._pendingOpeningLink {
            RootViewController._pendingOpeningLink = nil
            _open(pendingOpeningLink)
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
            sharedRootViewController._open(link)
        } else { _pendingOpeningLink = link }
    }
}

extension RootViewController {
    fileprivate static var _pendingOpeningLink: AnyLink?
    
    fileprivate func _open(_ link: AnyLink) {
        selectedIndex = 0
        
        guard let navigationController = viewControllers?.first as? ApplicationNavigationController else {
            Log.error("The first view controller is not ApplicationNavigationController.")
            return
        }
        
        navigationController.popToRootViewController(animated: true)
        
        let storyboard = UIStoryboard(name: "AnimePlayer", bundle: Bundle.main)
        guard let animeViewController = storyboard.instantiateInitialViewController() as? AnimeViewController else {
            Log.error("The view controller instantiated from AnimePlayer.storyboard is not AnimeViewController.")
            return
        }
        
        animeViewController.setPresenting(link)
        navigationController.pushViewController(animeViewController, animated: true)
    }
}
