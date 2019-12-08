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

import AVFoundation
import Foundation

/// Representing the state of the object
enum OfflineState {
    case ready
    case preservationInitiated
    case preserving(Float)
    case error(Error)
    case interrupted
    case preserved
}

/// A managed offline content item
///
/// This class should be subclassed to different kind to represent
/// the preservation of different contents.
///
/// When the content is in the `.preservationInitiated` or
/// `.ready` state, the subclasses have the responsibility to
/// update the state of this object. However, after the preservation
/// task has been initiated, this right is handed to the content
/// manager.
class OfflineContent: NSObject {
    var state: OfflineState {
        didSet {
            // Save the new state
            persistedLocalProperties()
            
            // Send state update notification
            if !isPendingRestoration {
                // Fire notification
                NotificationCenter.default.post(
                    name: .offlineAccessStateDidUpdate,
                    object: self
                )
            }
        }
    }
    
    var parent: OfflineContentManager
    
    var identifier: String { return "" }
    
    /// This property marks if this asset is still pending restoration
    ///
    /// - Note: Notifications for state changes are only sent after the asset has been restored
    var isPendingRestoration: Bool
    
    /// The provisioned downloading task of this OfflineContent
    var task: URLSessionTask? {
        // Observe changes to the task property
        didSet { taskPropertyDidChange(current: task, previous: oldValue) }
    }
    
    /// Access the date that the content is preserved
    var datePreserved: Date?
    
    /// Properties in this dictionary are persisted across launches
    var persistedProperties: [String: Any] {
        // Save local properties when updated
        didSet { persistedLocalProperties() }
    }
    
    /// Set to indicate if this asset is an persisted hls asset
    var isAggregatedAsset: Bool {
        get { return persistedProperties["aggregated"] as? Bool ?? false }
        set { persistedProperties["aggregated"] = newValue }
    }
    
    /// Used to recreate the persistent url
    ///
    /// Ideally no one besides the manager should access this property.
    /// Subclasses should use the `preservedContentURL` property to
    /// access the content.
    var persistentResourceIdentifier: (relativePath: String, relativeTo: String)?
    
    /// The data to resume the download task
    var resumeData: Data?
    
    /// Specify where to download the asset
    ///
    /// Subclasses should update the value of this variable and then let the `OfflineContent` class
    /// download and manage this asset
    var sourceRequestUrl: URL? {
        get {
            if let urlString = persistedProperties["sourceRequestUrl"] as? String {
                return URL(string: urlString)
            }
            return nil
        }
        set { persistedProperties["sourceRequestUrl"] = newValue?.absoluteString }
    }
    
    /// The request headers that should be sent along with the requests
    var sourceRequestHeaders: [String: String] {
        get { return persistedProperties["sourceRequestHeaders"] as? [String: String] ?? [:] }
        set { persistedProperties["sourceRequestHeaders"] = newValue }
    }
    
    /// Description of the downloading asset
    var localizedDescription: String {
        return "A Content"
    }
    
    /// Date at which the download was last attempted
    /// - Note: Although the property is stored by the `OfflineContent`, its value is maintained by the asset manager.
    var lastDownloadAttempt: Date?
    
    init(_ manager: OfflineContentManager, initialState: OfflineState) {
        state = initialState
        parent = manager
        persistedProperties = [:]
        isPendingRestoration = false
        
        super.init()
    }
    
    required init?(_ manager: OfflineContentManager, from properties: [String: Any], initialState: OfflineState) {
        state = initialState
        parent = manager
        persistedProperties = properties
        isPendingRestoration = true // Mark pending restoration as true
        
        super.init()
    }
    
    /// Retrive the name that the content should be named after
    /// the download finishes. Returned value shoud excludes extentension.
    ///
    /// The url passed into this function may not be the url
    /// that is persisted.
    func suggestName(for url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }
    
    /// Called when the resource is successfully downloaded to url
    func onCompletion(with url: URL) throws { }
    
    /// Called when the content should update the resource management policy for a system-managed asset
    func didAssignStoragePolicy(_ policy: AVAssetDownloadStorageManagementPolicy) {
        if isAggregatedAsset, let resourceUrl = preservedContentURL {
            AVAssetDownloadStorageManager
                .shared()
                .setStorageManagementPolicy(policy, for: resourceUrl)
        }
    }
    
    /// Called when an error from the downloading task is caught
    func onCompletion(with error: Error) { }
    
    /// Initiate preservation
    func preserve() {
        Log.error("[OfflineContent] Concrete classes did not inherit the preserve() method. Download may not work.")
    }
    
    /// Checks if the content still exists on file system and
    /// update the states accordingly.
    func updateResourceAvailability() {
        func fallbackToReady() {
            resumeData = nil
            task?.cancel()
            task = nil
            
            // Delete the files as well if it exists
            if persistentResourceIdentifier != nil {
                delete(shouldUpdateState: false)
            }
            
            state = .ready
        }
        
        // If the content is preserved, check if the resource is still available
        if case .preserved = state {
            // Check if the content is available and readable
            guard let url = preservedContentURL,
                FileManager.default.fileExists(atPath: url.path) else {
                fallbackToReady()
                return
            }
        }
        
        // If the content is interrupted, check if the resume data is presence,
        // or, in the case of AVAssetDownloadingURLSession, if the task is restored
        if case .interrupted = state {
            if let sessionType = persistedDownloadSessionType {
                if sessionType == "common" && resumeData == nil {
                    Log.info("A download task has invalid resume data. Fallbacking to ready state.")
                    fallbackToReady()
                }
                
                if sessionType == "avasset" && task == nil {
                    Log.info("A download task has invalid task reference. Fallbacking to ready state.")
                    fallbackToReady()
                }
                
                // What about if the session type is unknown??
            } else {
                Log.error("An interrupted content has an invalid session type")
                fallbackToReady()
            }
        }
    }
    
    /// Delete the preserved offline content
    func delete(shouldUpdateState: Bool = true) {
        // Cancel the task first
        cancel(shouldUpdateState: shouldUpdateState)
        
        // If the file exists, remove it
        if let url = preservedContentURL {
            do {
                try FileManager.default.removeItem(at: url)
                persistentResourceIdentifier = nil
            } catch { Log.error("[OfflineContent] Unable to remove content: %@", error) }
        }
        
        if shouldUpdateState {
            // Update state to ready
            state = .ready
        }
    }
    
    /// Cancel preservation
    func cancel(shouldUpdateState: Bool = true) {
        task?.cancel()
        task = nil
        
        if shouldUpdateState {
            state = .ready
        }
    }
    
    /// Resume the interruption if possible, restart the task if not
    func resumeInterruption() {
        // Only resume a task that is suspended or errored
        switch state {
        case _ where task?.state == .suspended:
            if let task = task {
                resumeInterruptedTask(task)
            }
        case _ where task?.state == .running:
            // Update state to preserving if the task is actually running
            state = .preserving(0.0)
        case .interrupted:
            if task == nil || task is AVAssetDownloadTask {
                fallthrough // Treat interrupted download task as failed
            } else if let task = task { resumeInterruptedTask(task) }
        case .preserved: break
        default: resumeFailedTask()
        }
    }
    
    /// Temporarily pause the content preservation
    func suspend() {
        // Only suspend a task that is preserving
        guard case .preserving = state else {
            return Log.error("Trying to suspend a task that is not preserving. Aborting.")
        }
        
        // Tell the task to suspend
        task?.suspend()
        state = .interrupted
    }
    
    /// Called when the content is restored from persistent storage
    func onRestore(persistentContent url: URL) { }
    
    /// Ask the content if it is able to restore the file from url
    ///
    /// The default behavior is to check if the target is an readable file
    func canRestore(persistentContent url: URL) -> Bool {
        let fs = FileManager.default
        return fs.fileExists(atPath: url.path)
    }
}

// MARK: - Resuming Tasks
private extension OfflineContent {
    /// Resume a paused task
    func resumeInterruptedTask(_ task: URLSessionTask) {
        Log.info("[OfflineContent] Resuming task (%@)", task.taskIdentifier)
        task.resume()
        state = .preserving(0.0)
    }
    
    /// Resume an errored task
    func resumeFailedTask() {
        // Delegate to `resumeFailedAggregatedTask()`
        if isAggregatedAsset {
            return resumeFailedAggregatedTask()
        }
        
        // If the resume data is present
        if let resumeData = resumeData {
            // Create and resume task with resume data
            self.task = downloadingSession.downloadTask(withResumeData: resumeData)
            self.resumeData = nil
        } else if let loadingUrl = sourceRequestUrl {
            self.delete(shouldUpdateState: false) // Remove the downloaded content
            self.task = downloadingSession.downloadTask(with: loadingUrl)
        } else {
            Log.info(
                "[OfflineContent] (Re)initiating preservation for '%@'.",
                localizedDescription
            )
            return preserve()
        }
        
        // Update state and attempt to resume the task
        state = .preserving(0.0)
        task?.resume()
    }
    
    /// Retry a failed aggregated asset task
    func resumeFailedAggregatedTask() {
        guard let downloadPackageLocation = preservedContentURL else {
            Log.error("[OfflineState] Cannot resume an aggregated task that does not contain a valid partially downloaded package.")
            return preserve()
        }
        
        // Create the URL Asset pointing to the downloaded package
        let recreatedUrlAsset = AVURLAsset(
            url: downloadPackageLocation,
            options: [ AVURLAssetHTTPHeaderFieldsKey: sourceRequestHeaders ]
        )
        
        // Using the AVAsset which indicates where the preserved parts are stored
        initAggregatedTask(withAsset: recreatedUrlAsset)
        task?.resume()
        state = .preserving(0.0)
    }
}

// MARK: - Initializing & Starting Tasks
extension OfflineContent {
    /// Create but not resume the download task for an aggregated asset
    ///
    /// - Important: Aggregated tasks should only be initiated with a `OfflineEpisodeContent`
    func initAggregatedTask(withAsset urlAsset: AVURLAsset) {
        guard let episodeContentSelf = self as? OfflineEpisodeContent else {
            return Log.error("[OfflineState] Aggregated content downloads should only be intiated by OfflineEpisodeContent.")
        }
        
        // Obtain task information
        let episodeLink = episodeContentSelf.episodeLink
        let artworkData = artwork(for: episodeLink.parent)?
            .jpegData(compressionQuality: 0.8)
        let episodeTitle = "\(episodeLink.parent.title) - Episode \(episodeLink.name)"
        
        // Initiate the download task with episodeLink
        task = assetDownloadingSession.makeAssetDownloadTask(
            asset: urlAsset,
            assetTitle: episodeTitle,
            assetArtworkData: artworkData,
            options: nil
        )
    }
    
    /// Start the downloading tasks
    ///
    /// - Important: Must be called after resource request parameters has been set
    func startResourceRequest() {
        guard let targetUrl = sourceRequestUrl else {
            return Log.error("[OfflineContent] Trying to start resource resources without setting sourceRequestUrl.")
        }
        
        if isAggregatedAsset {
            // Create the asset and init the task with `initAggregatedTask`
            let avAsset = AVURLAsset(
                url: targetUrl,
                options: [ AVURLAssetHTTPHeaderFieldsKey: sourceRequestHeaders ]
            )
            initAggregatedTask(withAsset: avAsset)
        } else {
            do {
                // Construct the URLRequest and persist with the normal download session
                let urlRequest = try URLRequest(
                    url: targetUrl,
                    method: .get,
                    headers: sourceRequestHeaders
                )
                task = downloadingSession.downloadTask(with: urlRequest)
            } catch {
                // Update state to error
                state = .error(error)
                return Log.error(
                    "[OfflineContent] Unable to construct URLRequest for content: %@",
                    error
                )
            }
        }
        
        // Update the state and resume the task
        state = .preserving(0.0)
        task?.resume()
    }
}

extension OfflineState {
    init(from dict: [String: Any]) {
        self = .ready
        if let type = dict["type"] as? String {
            switch type {
            case "ready": self = .ready
            // The following states are all handled as interrupted
            case "interrupted", "preserving": self = .interrupted
            case "error": self = .error(
                NineAnimatorError.contentUnavailableError(
                    dict["message", typedDefault: "Unknown Error"]
                )
            )
            case "preserved": self = .preserved
            case "queued": self = .preservationInitiated
            default: break
            }
        }
    }
    
    var export: [String: Any] {
        var dict = [String: Any]()
        switch self {
        case .ready: dict["type"] = "ready"
        case .preservationInitiated: dict["type"] = "queued"
        case .preserving(let progress):
            dict["type"] = "preserving"
            dict["progress"] = progress
        case .interrupted: dict["type"] = "interrupted"
        case let .error(error):
            dict["type"] = "error"
            dict["message"] = error.localizedDescription
        case .preserved: dict["type"] = "preserved"
        }
        return dict
    }
}
