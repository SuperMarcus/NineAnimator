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
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Update once in two hours
        UIApplication.shared.setMinimumBackgroundFetchInterval(
            UserNotificationManager.default.suggestedFetchInterval
        )
        UNUserNotificationCenter.current().delegate = UserNotificationManager.default
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let scheme = url.scheme else { return false }
        
        switch scheme {
        case "nineanimator":
            guard let resourceSpecifier = (url as NSURL).resourceSpecifier?[String.Index(encodedOffset: 2)...] else {
                Log.error("Cannot open url '%@': no resource specifier", url.absoluteString)
                return false
            }
            
            let animeUrlString = resourceSpecifier.hasPrefix("http") ? String(resourceSpecifier) : "https://\(resourceSpecifier)"
            
            guard let animeUrl = URL(string: animeUrlString) else {
                Log.error("Cannot open url '%@': invalid url", url.absoluteString)
                return false
            }
            
            let task = NineAnimator.default.link(with: animeUrl) {
                link, error in
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
                
                RootViewController.open(whenReady: link)
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
        
        //Perform fetch when app enters background
        UserNotificationManager.default.performFetch { _ in
            UIApplication.shared.endBackgroundTask(identifier)
        }
    }
    
    var taskPool: [NineAnimatorAsyncTask?]?
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.info("Received background fetch notification.")
        UserNotificationManager.default.performFetch(with: completionHandler)
    }
}
