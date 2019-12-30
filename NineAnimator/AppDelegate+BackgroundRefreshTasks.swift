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

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

import UIKit

@available(iOS 13.0, *)
extension AppDelegate {
    /// Identifier for the subscription update task
    fileprivate static let subscriptionUpdateTaskIdentifier = "com.marcuszhou.nineanimator.refresh.subscription"
    
    fileprivate func scheduleSubscriptionUpdateTasks() {
        do {
            let request = BGProcessingTaskRequest(
                identifier: AppDelegate.subscriptionUpdateTaskIdentifier
            )
            
            // Set the next scheduled date to 45 minutes from now
            let scheduledDate = Date(timeIntervalSinceNow: 45 * 60)
            request.earliestBeginDate = scheduledDate
            
            // Submit the request to the global scheduler
            try BGTaskScheduler.shared.submit(request)
            Log.debug("[AppDelegate] Scheduling the next refresh date to %@", scheduledDate)
        } catch {
            Log.error("[AppDelegate] Unable to submit background refresh task: %@", error)
        }
    }
    
    fileprivate func handleSubscriptionUpdateTask(_ task: BGProcessingTask) {
        Log.info("[AppDelegate] Running subscription update task...")
        
        // Schedule the next update
        scheduleSubscriptionUpdateTasks()
        
        let taskContainer = StatefulAsyncTaskContainer {
            container in
            task.setTaskCompleted(success: container.state != .failed)
            self.removeTask(container)
        }
        
        task.expirationHandler = {
            [weak taskContainer] in
            Log.debug("[AppDelegate] Subscription update task is about to expire. Pausing any running tasks...")
            taskContainer.unwrap {
                container in
                // Cancel the task
                container.cancel()
                self.removeTask(container)
            }
        }
        
        // Perform the fetch
        UserNotificationManager.default.performFetch(within: taskContainer)
        
        submitTask(taskContainer) // Save reference
        taskContainer.collect()
    }
}

// MARK: - Registering tasks
extension AppDelegate {
    /// Register NineAnimator's background refresh tasks
    func registerBackgroundUpdateTasks() {
        if #available(iOS 13.0, *) {
            // Using BackgroundTasks framework on iOS 13+
            let scheduler = BGTaskScheduler.shared
            
            // Subscription update task
            scheduler.register(
                forTaskWithIdentifier: AppDelegate.subscriptionUpdateTaskIdentifier,
                using: nil
            ) { task in self.handleSubscriptionUpdateTask(task as! BGProcessingTask) }
        } else {
            // Fetch for generating episode update notifications once in two hours
            UIApplication.shared.setMinimumBackgroundFetchInterval(
                UserNotificationManager.default.suggestedFetchInterval
            )
        }
    }
    
    /// Schedule the next run date for the background update tasks
    func scheduleBackgroundUpdateTasks() {
        if #available(iOS 13.0, *) {
            scheduleSubscriptionUpdateTasks()
        }
    }
}

// MARK: - Legacy Delegate Method
extension AppDelegate {
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.info("[AppDelegate] Beginning background fetching activities...")
        
        let container = StatefulAsyncTaskContainer {
            let finishedState = $0.state
            self.removeTask($0) // Remove reference to the container
            Log.error("[AppDelegate] Background fetching activities completed (%@)", finishedState)
            switch finishedState {
            case .failed: completionHandler(.failed)
            case .succeeded: completionHandler(.newData)
            case .unknown: completionHandler(.noData)
            }
        }
        
        UserNotificationManager.default.performFetch(within: container)
        
        // Mark as ready for collection
        container.collect()
        submitTask(container)
    }
}
