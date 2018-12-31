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
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        //Update once in two hours
        UIApplication.shared.setMinimumBackgroundFetchInterval(7200)
        return true
    }
    
    var taskPool: [NineAnimatorAsyncTask?]?
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let watchers = NineAnimator.default.user.watchedAnimes
        var resultsPool = [[EpisodeLink]?]()
        
        guard watchers.count > 0 else {
            completionHandler(.noData)
            return
        }
        
        func onFinalTask(){
            let succeededResultsCount = resultsPool
                .filter { return $0 != nil }
                .count
            let newResultsCount = resultsPool
                .filter { return ($0?.count ?? 0) > 0 }
                .count
            completionHandler(
                succeededResultsCount == watchers.count ?
                    newResultsCount > 0 ? .newData : .noData
                : .failed
            )
            debugPrint("[*] Background fetch is complete.")
            taskPool = nil
        }
        
        debugPrint("[*] Beginning background fetch with \(watchers.count) watched anime.")
        
        taskPool = watchers.map { return $0.updates {
            (error: Error?, watcher: NineAnimatorUser.WatchedAnime, diff: [EpisodeLink]) -> () in
            defer { if resultsPool.count == watchers.count { onFinalTask() } }
            
            if let error = error {
                resultsPool.append(nil)
                debugPrint("[!] Error: \(error)")
            } else {
                resultsPool.append(diff)
                debugPrint("[*] \(diff.count) new episodes found for '\(watcher.link.title)'.")
                
                //Send notification to user
                if diff.count > 0 {
                    let content = UNMutableNotificationContent()
                    
                    if diff.count == 1 {
                        let episode = diff.first!
                        content.title = "\(watcher.link.title)"
                        content.body = "Episode \(episode.name) is now available on \(watcher.link.source.name)."
                    } else {
                        content.title = "\(watcher.link.title)"
                        content.body = "\(diff.count) new episodes are now availble on \(watcher.link.source.name)."
                    }
                    
                    let request = UNNotificationRequest(
                        identifier: .episodeUpdateNotification,
                        content: content,
                        trigger: nil)
                    
                    UNUserNotificationCenter.current().add(request){
                        error in
                        if let error = error {
                            debugPrint("[*] Error posting notification: \(error)")
                        }
                    }
                }
            }
        } }
    }
}

fileprivate extension String {
    static var episodeUpdateNotification: String { return "com.marcuszhou.NineAnimator.notification.episodeUpdates" }
}
