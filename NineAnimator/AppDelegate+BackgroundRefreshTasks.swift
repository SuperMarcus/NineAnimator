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

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

import UIKit

/// Currently, both the refresh task and processing task are the same
@available(iOS 13.0, *)
extension AppDelegate {
    /// Identifier for the subscription update refresh task
    fileprivate static let subscriptionUpdateRefreshTaskIdentifier = "com.marcuszhou.nineanimator.refresh.subscription"
    
    /// Identifier for the subscription update processing task
    fileprivate static let subscriptionUpdateProcessingTaskIdentifier = "com.marcuszhou.nineanimator.processingTask.subscription"
    
    fileprivate func scheduleSubscriptionUpdateProcessingTasks() {
        do {
            let processingRequest = BGProcessingTaskRequest(
                identifier: AppDelegate.subscriptionUpdateProcessingTaskIdentifier
            )
            
            // Set the next scheduled date to 45 minutes from now
            let scheduledDate = Date(timeIntervalSinceNow: 45 * 60)
            processingRequest.earliestBeginDate = scheduledDate
            processingRequest.requiresExternalPower = false
            processingRequest.requiresNetworkConnectivity = true
            
            // Submit the request to the global scheduler
            try BGTaskScheduler.shared.submit(processingRequest)
            Log.debug("[AppDelegate] Scheduling the next processing date to %@", scheduledDate)
        } catch {
            Log.error("[AppDelegate] Unable to submit background processing task: %@", error)
        }
    }
    
    fileprivate func scheduleSubscriptionUpdateRefreshTasks() {
        do {
            let refreshRequest = BGAppRefreshTaskRequest(
                identifier: AppDelegate.subscriptionUpdateRefreshTaskIdentifier
            )
            
            // Set the next scheduled date to 30 minutes from now
            let scheduledDate = Date(timeIntervalSinceNow: 30 * 60)
            refreshRequest.earliestBeginDate = scheduledDate
            
            // Submit the request to the global scheduler
            try BGTaskScheduler.shared.submit(refreshRequest)
            Log.debug("[AppDelegate] Scheduling the next refresh date to %@", scheduledDate)
        } catch {
            Log.error("[AppDelegate] Unable to submit background refresh task: %@", error)
        }
    }
    
    /// Both the processing task and app refresh task will call this method
    fileprivate func handleSubscriptionUpdateTask(_ task: BGTask) {
        Log.info("[AppDelegate] Running subscription update background task...")
        
        // Schedule the next update
        if task is BGProcessingTask {
            scheduleSubscriptionUpdateProcessingTasks()
        } else {
            scheduleSubscriptionUpdateRefreshTasks()
        }
        
        let taskContainer = StatefulAsyncTaskContainer {
            container in
            self.removeTask(container)
            task.setTaskCompleted(success: container.state != .failed)
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
            task.setTaskCompleted(success: false)
        }
        
        // Perform the fetch
        UserNotificationManager.default.performFetch(within: taskContainer)
        
        submitTask(taskContainer) // Save reference
        taskContainer.collect()
    }
}

// MARK: - Registering tasks
extension AppDelegate {
    /// Register NineAnimator's background tasks
    func registerBackgroundUpdateTasks() {
        if #available(iOS 13.0, *) {
            // Using BackgroundTasks framework on iOS 13+
            let scheduler = BGTaskScheduler.shared
            
            // Subscription update processing task
            scheduler.register(
                forTaskWithIdentifier: AppDelegate.subscriptionUpdateProcessingTaskIdentifier,
                using: nil
            ) { task in self.handleSubscriptionUpdateTask(task) }
            
            // Subscription update refresh task
            scheduler.register(
                forTaskWithIdentifier: AppDelegate.subscriptionUpdateRefreshTaskIdentifier,
                using: nil
            ) { task in self.handleSubscriptionUpdateTask(task) }
        } else {
            // Fetch for generating episode update notifications once in two hours
            UIApplication.shared.setMinimumBackgroundFetchInterval(
                UserNotificationManager.default.suggestedFetchInterval
            )
        }
    }
    
    /// Schedule the next run date for all background tasks
    func scheduleAllBackgroundTasks() {
        if #available(iOS 13.0, *) {
            scheduleSubscriptionUpdateProcessingTasks()
            scheduleSubscriptionUpdateRefreshTasks()
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
        
        // Submit task and mark container as ready for collection
        submitTask(container)
        container.collect()
    }
}
