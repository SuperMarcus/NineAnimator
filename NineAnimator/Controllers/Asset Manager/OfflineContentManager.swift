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

import AVKit
import Foundation

///
/// Manages offline contents such as downloads
///
/// Note that this class is seperate from the NotificationManager
/// because they have different purposes. The OfflineContentManager
/// is implemented to permanently preserve data offline, not for
/// caching.
///
class OfflineContentManager: NSObject, AVAssetDownloadDelegate, URLSessionDownloadDelegate {
    static let shared = OfflineContentManager()
    
    /// The queue used to execute `OfflineContentManager` tasks
    private(set) var taskQueue = DispatchQueue(label: "com.marcuszhou.nineanimator.OfflineContent")
    
    /// The maximal number of concurrent tasks
    fileprivate var maximalConcurrentTasks: Int { 3 }
    
    /// The time between each download attempts
    fileprivate var minimalRetryInterval: TimeInterval { 30 }
    
    /// A delay timer used for delaying download retries
    fileprivate var dequeueDelayTimer: Timer?
    
    fileprivate var screenOnRequestHandler: AppDelegate.ScreenOnRequestHandler?
    fileprivate var preventSuspensionRequestHandler: AppDelegate.PreventSuspensionRequestHandler?
    
    fileprivate var backgroundSessionCompletionHandler: (() -> Void)?
    
    fileprivate var persistedContentIndexURL: URL {
        persistentDirectory
            .appendingPathComponent("com.marcuszhou.nineanimator.offlinecontents.index.plist")
    }
    
    fileprivate var persistedContentList: [String: [String: Any]] {
        get {
            do {
                let data = try Data(contentsOf: persistedContentIndexURL)
                guard let dict = try PropertyListSerialization
                    .propertyList(from: data, options: [], format: nil) as? [String: [String: Any]] else {
                        throw NineAnimatorError.providerError("Error decoding property listed file")
                }
                return dict
            } catch { Log.error(error) }
            return [:]
        }
        set {
            do {
                try PropertyListSerialization
                    .data(fromPropertyList: newValue, format: .binary, options: 0)
                    .write(to: persistedContentIndexURL, options: [ .atomic ])
            } catch { Log.error(error) }
        }
    }
    
    fileprivate lazy var sharedAssetSession: AVAssetDownloadURLSession = {
        let sessionConfiguration: URLSessionConfiguration =
            .background(withIdentifier: "com.marcuszhou.nineanimator.urlsession.avasset")
//        sessionConfiguration.isDiscretionary = true
        sessionConfiguration.sessionSendsLaunchEvents = true
        let session = AVAssetDownloadURLSession(
            configuration: sessionConfiguration,
            assetDownloadDelegate: self,
            delegateQueue: nil
        )
        return session
    }()
    
    fileprivate lazy var sharedSession: URLSession = {
        let sessionConfiguration: URLSessionConfiguration =
            .background(withIdentifier: "com.marcuszhou.nineanimator.urlsession.asset")
//        sessionConfiguration.isDiscretionary = true
        sessionConfiguration.sessionSendsLaunchEvents = true
        let session = URLSession(
            configuration: sessionConfiguration,
            delegate: self,
            delegateQueue: nil
        )
        return session
    }()
    
    /// NineAnimator's offline content persistent directory
    fileprivate var persistentDirectory: URL {
        do {
            let fs = FileManager.default
            
            // According to the guidelines, the recreatable
            // materials should be stored in cache directory
            let cacheDiractory = try fs.url(
                for: .cachesDirectory,
                in: .allDomainsMask,
                appropriateFor: nil,
                create: true
            )
            let persistentDirectory = cacheDiractory.appendingPathComponent("com.marcuszhou.nineanimator.OfflineContents")
            
            // Create the directory if it does not exists
            try fs.createDirectory(
                at: persistentDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            return persistentDirectory
        } catch {
            Log.error("[OfflineContentManager] Cannot obtain persistent directory: %@. This is an fatal error and the app cannot continue.", error)
            // Should I handle this error?
            fatalError("Cannot obtain OfflineContents directory")
        }
    }
    
    /// User home directory, for `AVAssetDownloadURLSession` downloaded contents
    fileprivate var homeDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory())
    }
    
    private lazy var registeredContentTypes: [String: ([String: Any], OfflineState) -> OfflineContent?] = {
        var typeRegistry = [String: ([String: Any], OfflineState) -> OfflineContent?]()
        
        typeRegistry["OfflineEpisodeContent"] = {
            OfflineEpisodeContent(self, from: $0, initialState: $1)
        }
        
        return typeRegistry
    }()
    
    /// An array to store references to contents
    private lazy var contentPool = persistedContentPool.map {
        content -> OfflineContent in
        if case .preservationInitiated = content.state {
            preservationContentQueue.append(content)
        }
        return content
    }
    
    /// A FIFO queue for preservation tasks
    private(set) var preservationContentQueue = [OfflineContent]()
}

// MARK: - Accessing Tasks
extension OfflineContentManager {
    /// Retrieve a list of preserved contents
    var preservedContents: [OfflineContent] {
        contentPool.filter {
            $0.updateResourceAvailability()
            if case .preserved = $0.state { return true }
            return false
        }
    }
    
    /// Retrieve a list of preserved or preserving contents
    var statefulContents: [OfflineContent] {
        contentPool.filter {
            if case .interrupted = $0.state { return true }
            if case .preserving = $0.state { return true }
            if case .preservationInitiated = $0.state { return true }
            if case .error = $0.state { return true }
            
            // Update availability before deciding if this content is preserved
            $0.updateResourceAvailability()
            if case .preserved = $0.state { return true }
            
            // Default to no
            return false
        }
    }
    
    /// A list of anime that have episodes being preserved
    var statefulAnime: [AnimeLink] {
        let listOfAnime = statefulContents
            .compactMap { $0 as? OfflineEpisodeContent }
            .map { $0.episodeLink.parent }
        var uniqueAnime = [AnimeLink]()
        for anime in listOfAnime where !uniqueAnime.contains(anime) {
            uniqueAnime.append(anime)
        }
        return uniqueAnime
    }
    
    /// Obtain the list of episode content under the anime
    func contents(for anime: AnimeLink) -> [OfflineEpisodeContent] {
        statefulContents
            .compactMap { $0 as? OfflineEpisodeContent }
            .filter { $0.episodeLink.parent == anime }
    }
    
    /// Obtain the corresponding `OfflineEpisodeContent` for the episodeLink
    func content(for episodeLink: EpisodeLink) -> OfflineEpisodeContent {
        if let content = contentPool
            .compactMap({ $0 as? OfflineEpisodeContent })
            .first(where: { $0.episodeLink == episodeLink }) {
            content.updateResourceAvailability()
            return content
        } else {
            let content = OfflineEpisodeContent(episodeLink, parent: self)
            contentPool.append(content)
            return content
        }
    }
    
    /// Obtain the state of the EpisodeLink object
    func state(for episodeLink: EpisodeLink) -> OfflineState {
        content(for: episodeLink).state
    }
    
    /// Cancel all preservations of episodes under this anime link
    func cancelPreservations(forEpisodesOf animeLink: AnimeLink) {
        contents(for: animeLink).forEach {
            cancelPreservation(content: $0)
        }
    }
    
    /// Cancel and remove the preservation (if in progress) for episode
    func cancelPreservation(for episodeLink: EpisodeLink) {
        cancelPreservation(content: content(for: episodeLink))
    }
    
    /// Remove all preserved content under the anime link
    func removeContents(under animeLink: AnimeLink) {
        contents(for: animeLink).forEach { $0.delete() }
    }
}

// MARK: - Task Queue Management
extension OfflineContentManager {
    /// The number of downloading tasks that is currently running
    var numberOfPreservingTasks: Int {
        contentPool.reduce(0) {
            if case .preserving = $1.state {
                return $0 + 1
            } else { return $0 }
        }
    }
    
    /// Start preserving the episode
    func initiatePreservation(for episodeLink: EpisodeLink, withLoadedAnime anime: Anime? = nil) {
        let content = self.content(for: episodeLink)
        initiatePreservation(episodeContent: content, withLoadedAnime: anime)
    }
    
    /// Cancel and remove the content from the storage
    func cancelPreservation(content: OfflineContent) {
        // Remove from queue
        preservationContentQueue.removeAll { $0 == content }
        content.delete()
        content.counter.resetCounter() // Reset retry counter
        preserveContentIfNeeded()
    }
    
    /// Start the preservation of the episode with an optional cached anime
    func initiatePreservation(episodeContent: OfflineEpisodeContent, withLoadedAnime anime: Anime? = nil) {
        episodeContent.anime = anime
        initiatePreservation(content: episodeContent)
    }
    
    /// Start preserving the content, resume if possible
    func initiatePreservation(content: OfflineContent) {
        if preservationContentQueue.contains(content) {
            return preserveContentIfNeeded()
        }
        content.updateResourceAvailability()
        
        switch content.state {
        case .preservationInitiated, .preserving, .preserved: break
        default:
            // Enqueue the content
            preservationContentQueue.append(content)
            content.state = .preservationInitiated
            preserveContentIfNeeded()
        }
    }
    
    /// Pause the downloading content and remove it from the preserving queue
    func suspendPreservation(content: OfflineContent) {
        // Remove from queue
        preservationContentQueue.removeAll { $0 == content }
        content.suspend()
        preserveContentIfNeeded()
    }
    
    /// Pause the specified downloading contents and remove them from the preserving queue
    func suspendPreservations(contents: [OfflineContent]) {
        let contentsSet = Set(contents)
        preservationContentQueue.removeAll {
            contentsSet.contains($0)
        }
        contents.forEach { $0.suspend() }
        preserveContentIfNeeded()
    }
    
    /// Dequeue a content that is going to be preserved and start its prepservation
    private func preserveQueuedContents(maximalCount: Int = 1) {
        // First invalidate any previous delay timers
        dequeueDelayTimer?.invalidate()
        dequeueDelayTimer = nil
        
        if !preservationContentQueue.isEmpty {
            let realisticCount = min(
                preservationContentQueue.count,
                maximalCount
            )
            
            var startDelay = DispatchTime.now() + .milliseconds(100)
            var reEnqueuingContents = [OfflineContent]()
            
            for content in preservationContentQueue[0..<realisticCount] {
                // If the download was attempted within the minimal retry interval
                if !content.shouldIgnoreMinimalRetryInterval,
                    let lastDownloadAttempt = content.lastDownloadAttempt,
                    lastDownloadAttempt.timeIntervalSinceNow > -minimalRetryInterval {
                    reEnqueuingContents.append(content)
                    continue
                }
                
                taskQueue.asyncAfter(deadline: startDelay, flags: [ .barrier ]) {
                    content.resumeInterruption()
                    content.lastDownloadAttempt = Date()
                }
                // swiftlint:disable shorthand_operator
                startDelay = startDelay + .milliseconds(100)
                // swiftlint:enable shorthand_operator
            }
            
            // Remove the contents that have been restarted
            preservationContentQueue = reEnqueuingContents + preservationContentQueue[realisticCount...]
            
            // Request the screen to be kept on while there are items in the queue
            screenOnRequestHandler = AppDelegate.shared?.requestScreenOn()
            
            // Request the app to play audio to prevent it from going into the background
            preventSuspensionRequestHandler = AppDelegate.shared?.requestAppFromBeingSuspended()
            
            // If there are items in the delay list, schedule a timer
            if let largestInterval = reEnqueuingContents.compactMap({
                    $0.lastDownloadAttempt?.timeIntervalSinceNow
                }).min(), minimalRetryInterval + largestInterval > 0 {
                // Delay interval+1s
                let delayInterval = max(minimalRetryInterval + largestInterval + 1, 1)
                
                // Schedule the retry timer
                DispatchQueue.main.async {
                    [weak self] in
                    self?.dequeueDelayTimer?.invalidate()
                    self?.dequeueDelayTimer = Timer.scheduledTimer(withTimeInterval: delayInterval, repeats: false) {
                        _ in
                        Log.debug("[OfflineContentManager] Dequeue delay timer fired.")
                        self?.preserveContentIfNeeded()
                    }
                    Log.debug("[OfflineContentManager] Scheduling a delay timer for an interval of %@ seconds for the next dequeue.", delayInterval)
                }
            }
        } else {
            screenOnRequestHandler = nil
            preventSuspensionRequestHandler = nil
        }
    }
    
    /// Preserve the next queued contents if the number of tasks drop to below the threshold
    func preserveContentIfNeeded() {
        taskQueue.async(flags: [ .barrier ]) {
            guard NineAnimator.default.reachability?.isReachable == true else {
                return Log.info("[OfflineContentManager] Network currently unreachable. Contents will be preserved later.")
            }
            
            guard let appDelegate = AppDelegate.shared,
                  appDelegate.isActive || self.preventSuspensionRequestHandler != nil else {
                return Log.info("[OfflineContentManager] App is suspended. More contents will be preserved later.")
            }
            
            let availableSpots = self.maximalConcurrentTasks - self.numberOfPreservingTasks
            if availableSpots > 0 {
                self.preserveQueuedContents(maximalCount: availableSpots)
            }
        }
    }
    
    /// Called when the download has failed for an OfflineContent and it is requesting to be
    /// re-enqueued into the download queue
    fileprivate func enqueueFailedDownloadingContent(content: OfflineContent) {
        Log.info(
            "[OfflineContentManager] Re-enqueued failed content '%@' to the download queue",
            content.localizedDescription
        )
        preservationContentQueue.insert(content, at: 0)
        content.state = .preservationInitiated
        preserveContentIfNeeded()
    }
}

// MARK: - URLSession Delegate
extension OfflineContentManager {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard session == sharedSession,
            let content = content(for: downloadTask, inSession: session) else {
            return
        }
        
        defer {
            content.persistedLocalProperties()
            // Call the background session completion handler
            backgroundSessionCompletionHandler?()
            backgroundSessionCompletionHandler = nil
        }
        
        let fs = FileManager.default
        
        // Move content to the download folder
        do {
            let illegalCharacters = CharacterSet(charactersIn: "/*:<>?%|")
            let newName = content.suggestName(for: location)
                .components(separatedBy: illegalCharacters)
                .joined(separator: "_")
            let pathExtension = downloadTask.response?.suggestedFilename?.split(separator: ".").last ?? "bin"
            let resourceIdentifierPath = "\(newName).\(pathExtension)"
            
            // Set resource identifier
            content.persistentResourceIdentifier = (resourceIdentifierPath, "persist")
            
            guard var destinationUrl = content.preservedContentURL else {
                throw NineAnimatorError.providerError("Cannot retrieve url when resource identifier has been set")
            }
            
            if (try? destinationUrl.checkResourceIsReachable()) == true {
                Log.error("[OfflineContentManager] Duplicated file detected, removing.")
                try fs.removeItem(at: destinationUrl)
            }
            
            // Move the item
            try fs.copyItem(at: location, to: destinationUrl)
            try? fs.removeItem(at: location) // Fails on jailbroken devices
            
            // Set the resource to be excluded from backups
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try destinationUrl.setResourceValues(resourceValues)
            
            // Update: The internal completion handler is now called within
            // didCompleteWithError
            // # Call the internal completion handler
            // content._onCompletion(session)
        } catch {
            Log.error("[OfflineContentManager] Failed to move the downloaded asset for task (%@): %@", downloadTask.taskIdentifier, error)
            content.persistentResourceIdentifier = nil
            content._onCompletion(session, error: error)
            try? fs.removeItem(at: location) // Remove the item
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Log.info(
            "[OfflineContentManager] Downlaod task (%@) for session %@ has completed.",
            task.taskIdentifier,
            session.configuration.identifier ?? "[Unknown Identifier]"
        )
        
        // If the task does not belong to the normal session, call the AVAssetDownloadSession's
        // delegated method
        guard session == sharedSession else {
            return assetDownloadTask(session, task: task, didCompleteWithError: error)
        }
        
        // Obtain the content
        guard let content = content(for: task, inSession: session) else { return }
        
        if let error = error {
            // Save the resume data if possible
            if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                Log.info("[OfflineContentManager] The failed task (%@) may be resumable", task.taskIdentifier)
                content.resumeData = resumeData
            }
            
            // Call the handler method
            content._onCompletion(session, error: error)
        } else {
            content._onCompletion(session)
            preserveContentIfNeeded()
        }
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard session == sharedSession,
            let content = content(for: downloadTask, inSession: session) else {
            return
        }
        
        let progress = (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) ?
            0.9 : Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        content._onProgress(session, progress: progress)
    }
    
    private func content(for task: URLSessionTask, inSession session: URLSession) -> OfflineContent? {
        let searchForAggregated: Bool
        if session == sharedAssetSession {
            searchForAggregated = true
        } else if session == sharedSession {
            searchForAggregated = false
        } else { return nil }
        
        var matchingIdentifierContent: OfflineContent?
        
        for content in contentPool where content.isAggregatedAsset == searchForAggregated {
            // If the same task is found, return the content that owns the task
            if content.task == task {
                return content
            }
            
            // Stores the content that has the same task identifier
            if content.persistedTaskIdentifier == task.taskIdentifier {
                matchingIdentifierContent = content
            }
        }
        
        // Returning the content with the matching identifier
        return matchingIdentifierContent
    }
}

// MARK: - AVAssetSession Delegate
extension OfflineContentManager {
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard session == sharedAssetSession,
            let content = content(for: assetDownloadTask, inSession: session) else {
            // To prevent possible storage leak, remove the item
            _ = try? FileManager.default.removeItem(at: location)
            return Log.error(
                "[OfflineContentManager] AVAssetDownloadTask(%@) didFinishDownloadingTo %@, but no OfflineContent is available to handle this task. Deleting downloaded asset.",
                assetDownloadTask.taskIdentifier,
                location.relativePath
            )
        }
        
        defer {
            content.persistedLocalProperties()
            // Call the background session completion handler
            backgroundSessionCompletionHandler?()
            backgroundSessionCompletionHandler = nil
        }
        
        Log.info(
            "[OfflineContentManager] AVAsset '%@' (%@) did download to '%@'",
            content.localizedDescription,
            assetDownloadTask.taskIdentifier,
            location.relativePath
        )
        
        // Save the resource location
        content.persistentResourceIdentifier = (location.relativePath, "home")
    }
    
    func urlSession(_ session: URLSession,
                    assetDownloadTask: AVAssetDownloadTask,
                    didLoad timeRange: CMTimeRange,
                    totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                    timeRangeExpectedToLoad: CMTimeRange) {
        guard session == sharedAssetSession,
            let content = content(for: assetDownloadTask, inSession: session) else {
            // If there's no record of this task, cancel it
            assetDownloadTask.cancel()
            return Log.error(
                "[OfflineContentManager] Received progress update from AVAssetDownloadTask(%@), but no OfflineContent is available to handle this task. Canceling this task.",
                assetDownloadTask.taskIdentifier
            )
        }
        
        // Calculate the progress
        let progress = loadedTimeRanges
            .map { $0.timeRangeValue.duration.seconds }
            .reduce(0.0, +) / timeRangeExpectedToLoad.duration.seconds
        
        content._onProgress(session, progress: Double(progress))
    }
    
    /// Delegated from `urlSession(_ session:, task:, didCompleteWithError:)`
    func assetDownloadTask(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard session == sharedAssetSession,
            let assetDownloadTask = task as? AVAssetDownloadTask,
            let content = content(for: assetDownloadTask, inSession: session) else {
            return Log.error(
                "[OfflineContentManager] AVAssetDownloadTask(%@) didCompleteWithError(%@) called but no OfflineContent is available to handle it.",
                task.taskIdentifier,
                error ?? "<nil>"
            )
        }
        
        if let error = error { // If the download failed
            content._onCompletion(session, error: error)
        } else {
            content._onCompletion(session)
            content.didAssignStoragePolicy(storagePolicy)
            preserveContentIfNeeded()
        }
    }
}

// MARK: - Restoring Pending Tasks
extension OfflineContentManager {
    /// Called upon app launch to fetch any incomplete tasks
    func recoverPendingTasks() {
        recoverSharedSessionPendingTasks()
        recoverSharedAssetSessionPendingTasks()
    }
    
    /// Restore pending tasks in the shared URL session
    private func recoverSharedSessionPendingTasks() {
        // Restore persisted session tasks
        sharedSession.getAllTasks {
            tasks in
            let contents = self.contentPool.filter {
                $0.persistedDownloadSessionType == "common"
            }
            
            // Assign tasks to the contents
            for task in tasks {
                if let content = contents.first(where: { $0.persistedTaskIdentifier == task.taskIdentifier }) {
                    Log.info("[OfflineContentManager] URLSession download task with identifeir %@ is found", task.taskIdentifier)
                    content.isPendingRestoration = true
                    content.task = task
                    // Suspend the task so it doesn't resume until we wants it to
                    task.suspend()
                } else {
                    Log.info("[OfflineContentManager] URLSession download task with identifeir %@ is found, but no content is availble to hanlde it. Cancelling task.", task.taskIdentifier)
                    task.cancel()
                }
            }
            
            // Trying to resume the tasks
            if NineAnimator.default.user.autoRestartInterruptedDownloads {
                Log.info("[OfflineContentManager] Automatically resuming any unfinished downloads for the shared URLSession")
                for content in contents where content.isPendingRestoration {
                    content.isPendingRestoration = false
                    content.state = .preservationInitiated
                    self.preservationContentQueue.append(content)
                }
                self.preserveContentIfNeeded()
            } else {
                contents.forEach { // Mark all contents as restored
                    $0.isPendingRestoration = false
                }
            }
        }
    }
    
    /// Restore pending tasks in the shared AVAsset download session
    private func recoverSharedAssetSessionPendingTasks() {
        sharedAssetSession.getAllTasks {
            tasks in
            let contents = self.contentPool.filter {
                $0.persistedDownloadSessionType == "avasset"
            }
            
            // Assign tasks to the contents
            for task in tasks {
                if let content = contents.first(where: { $0.persistedTaskIdentifier == task.taskIdentifier }) {
                    Log.info("[OfflineContentManager] AVAssetDownloadingURLSession download task with identifeir %@ is found", task.taskIdentifier)
                    content.isPendingRestoration = true
                    content.task = task
                } else {
                    Log.info("[OfflineContentManager] AVAssetDownloadingURLSession download task with identifeir %@ is found, but no content is availble to hanlde it. Cancelling task.", task.taskIdentifier)
                    task.cancel()
                }
            }
            
            // Trying to resume the tasks
            if NineAnimator.default.user.autoRestartInterruptedDownloads {
                // Wait for 3 seconds until restoring the tasks
                self.taskQueue.asyncAfter(deadline: .now() + .milliseconds(3000), flags: [ .barrier ]) {
                    Log.info("[OfflineContentManager] Automatically resuming any unfinished downloads for the shared asset session")
                    for content in contents where content.isPendingRestoration {
                        content.isPendingRestoration = false
                        content.state = .preservationInitiated
                        content.task?.suspend()
                        self.preservationContentQueue.append(content)
                    }
                    self.preserveContentIfNeeded()
                }
            } else {
                contents.forEach { // Mark all contents as restored
                    $0.isPendingRestoration = false
                }
            }
        }
    }
}

// MARK: - Managing Assets
extension OfflineContentManager {
    /// Parse OfflineContent from file system
    private var persistedContentPool: [OfflineContent] {
        persistedContentList.compactMap {
            item -> OfflineContent? in
            let dict = item.value
            guard let type = dict["type"] as? String,
                let stateDict = dict["state"] as? [String: Any],
                let properties = dict["properties"] as? [String: Any] else { return nil }
            
            let state = OfflineState(from: stateDict)
            
            // The content is restored with the initial state
            guard let content = registeredContentTypes[type]?(properties, state) else { return nil }
            
            if case .preserved = state {
                if let relativePath = dict["path"] as? String,
                    let relativeTo = dict["relative"] as? String {
                    content.persistentResourceIdentifier = (relativePath, relativeTo)
                    
                    // Ask the content itself if it is able to restore the offline content
                    if let url = content.preservedContentURL,
                        content.canRestore(persistentContent: url) {
                        content.datePreserved = (dict["date"] as? Date) ?? Date()
                        content.onRestore(persistentContent: url)
                        return content
                    }
                }
                
                Log.error("[OfflineContentManager] A preserved resource is unrestorable. Resetting to ready state.")
                
                // If the url cannot be restored, reset state to ready
                content.delete(shouldUpdateState: false)
                content.persistentResourceIdentifier = nil
                content.state = .ready
            }
            
            // Restore the resume data
            if let resumeData = dict["resumeData"] as? Data {
                content.resumeData = resumeData
            }
            
            return content
        } .filter {
            // Only return contents that are not 'ready' nor 'error'
            switch $0.state {
            case .ready: return false
            default: return true
            }
        }
    }
    
    /// Parse and update the persisted content pool from the file system
    fileprivate func readPersistedContents() {
        contentPool = persistedContentPool
    }
    
    /// Remove all downloaded contents - free up the disk space
    func deleteAll() {
        do {
            Log.info("Removing all persisted contents")
            
            let fs = FileManager.default
            
            // First, tell all the contents to clean up after themselves
            preservedContents.forEach { $0.delete() }
            
            // List and remove files from the persistent directory
            try fs.contentsOfDirectory(
                at: persistentDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsSubdirectoryDescendants]
            ).forEach { try fs.removeItem(at: $0) }
            
            // Last, remove references to all contents
            contentPool = []
        } catch { Log.error("Faild to clean persist directory: %@", error) }
    }
    
    /// Update the preserved contents' storage policy
    func updateStoragePolicies() {
        let policy = storagePolicy
        for content in contentPool where content.isAggregatedAsset {
            if case .preserved = content.state {
                content.didAssignStoragePolicy(policy)
            }
        }
    }
    
    /// Listening on new task creation
    fileprivate func contentDidCreateNewTask(_ task: URLSessionTask, fromContent source: OfflineContent) {
        // If the newly created task has the same identifier as one of the old content,
        // remove the duplicated task identifier of the old content
        for content in contentPool where content != source
            && content.isAggregatedAsset == source.isAggregatedAsset
            && content.persistedTaskIdentifier == task.taskIdentifier {
            Log.info(
                "[OfflineContentManager] Removing duplicated content identifier (%@) from content %@",
                task.taskIdentifier,
                content.localizedDescription
            )
            content.removePersistedTaskIdentifier()
        }
    }
    
    /// Obtain the storage policy for each AVAsset download items
    fileprivate var storagePolicy: AVAssetDownloadStorageManagementPolicy {
        let mutablePolicy = AVMutableAssetDownloadStorageManagementPolicy()
        mutablePolicy.expirationDate = .distantFuture
        mutablePolicy.priority = NineAnimator.default.user.preventAVAssetPurge
            ? .important : .default
        return mutablePolicy
    }
}

// MARK: - Usage Statistics
extension OfflineContentManager {
    struct DownloadStorageStatistics {
        var totalBytes: Int = 0
        var numberOfAssets: Int = 0
    }
    
    /// Fetch the storage usage of all downloaded contents
    func fetchDownloadStorageStatistics() -> NineAnimatorPromise<DownloadStorageStatistics> {
        let fs = FileManager.default
        return NineAnimatorPromise<[Int]>.queue(listOfPromises: contentPool.compactMap {
            $0.updateResourceAvailability()
            return $0.preservedContentURL
        } .map { fs.sizeOfItem(atUrl: $0) }).then {
            $0.reduce(into: DownloadStorageStatistics()) {
                $0.totalBytes += $1
                $0.numberOfAssets += 1
            }
        }
    }
}

// MARK: - Exposed to Assets
extension OfflineContent {
    var assetDownloadingSession: AVAssetDownloadURLSession { parent.sharedAssetSession }
    
    var downloadingSession: URLSession { parent.sharedSession }
    
    /// The url on the file system to where the offline content is stored
    ///
    /// Set by the manager
    var preservedContentURL: URL? {
        guard let resourceIdentifier = self.persistentResourceIdentifier else {
            return nil
        }
        
        let path = resourceIdentifier.relativePath
        switch resourceIdentifier.relativeTo {
        case "home":
            return URL(fileURLWithPath: path, relativeTo: parent.homeDirectory)
        case "persist":
            return URL(fileURLWithPath: path, relativeTo: parent.persistentDirectory)
        default: return nil
        }
    }
    
    /// The persisted task identifier
    var persistedTaskIdentifier: Int? {
        parent.persistedContentList[identifier]?["taskIdentifier"] as? Int
    }
    
    /// The persisted session type
    var persistedDownloadSessionType: String? {
        parent.persistedContentList[identifier]?["session"] as? String
    }
    
    /// Specify if minimal retry interval should be ignored for this content
    fileprivate var shouldIgnoreMinimalRetryInterval: Bool {
        task?.state == .suspended
    }
    
    /// Remove the persisted task identifier
    fileprivate func removePersistedTaskIdentifier() {
        parent.persistedContentList[identifier]?["taskIdentifier"] = nil
    }
    
    fileprivate func _onCompletion(_ session: URLSession) {
        // Check if preserved content location is saved
        guard let location = preservedContentURL else {
            persistentResourceIdentifier = nil
            Log.error("Location cannot be retrived after resource identifier has been set")
            return _onCompletion(
                session,
                error: NineAnimatorError.providerError("Location cannot be identified")
            )
        }
        
        // Check if download file exists
        guard FileManager.default.fileExists(atPath: location.path) else {
            persistentResourceIdentifier = nil
            Log.error("[OfflineContent] Downloaded resource is unreachable")
            return _onCompletion(
                session,
                error: NineAnimatorError.providerError("Unreachable offline content")
            )
        }
        
        // Check the validity of the downloaded avasset
        if let task = task as? AVAssetDownloadTask,
            task.urlAsset.assetCache?.isPlayableOffline != true {
            // For some reason, isPlayableOffline may be set to false after
            // a successful download. Downloads seem to be playing fine so
            // ignoring this for now.
            Log.error("[OfflineContent] This is weired. Asset finished downloading without an error but is marked as not playable offline. Expecting problems with offline playback.")
        }
        
        do {
            try onCompletion(with: location)
        } catch { return _onCompletion(session, error: error) }
        
        if isAggregatedAsset { // For aggregated assets, update the cache flags
            adjustCacheStrategy(forPackagedResource: location)
        }
        
        Log.info("[OfflineContent] Content persisted to %@", location.absoluteString)
        
        // Update state and call completion handler
        datePreserved = Date()
        state = .preserved
    }
    
    fileprivate func _onCompletion(_ session: URLSession, error: Error) {
        switch state {
        case .ready: break
        default:
            Log.info("[OfflineContent] Content persistence finished with error: %@", error)
            onCompletion(with: error)
            
            if NineAnimator.default.user.autoRestartInterruptedDownloads, !isPendingRestoration {
                parent.enqueueFailedDownloadingContent(content: self)
            } else { state = .error(error) }
        }
    }
    
    fileprivate func _onProgress(_ session: URLSession, progress: Double) {
        if case .preserving = state {
            state = .preserving(Float(progress))
        } else {
            Log.error(
                "[OfflineContent] Progress for %@ updated to %@ while the current state is %@.",
                self.localizedDescription,
                progress,
                state
            )
        }
    }
    
    // Encode and stores the persistent information for this content on the file system
    func persistedLocalProperties() {
        switch state {
        case .ready:
            // Remove the content from store if it is errored or ready
            parent.persistedContentList[identifier] = nil
            return
        default: break
        }
        
        if !identifier.isEmpty {
            var entry = parent.persistedContentList[identifier] ?? [:]
            entry["type"] = String(describing: type(of: self))
            entry["properties"] = persistedProperties
            entry["state"] = state.export
            
            if let resourceIdentifier = persistentResourceIdentifier {
                entry["path"] = resourceIdentifier.relativePath
                entry["relative"] = resourceIdentifier.relativeTo
            }
            
            if let date = datePreserved {
                // Save the date that this asset is persisted
                entry["date"] = date as NSDate
            }
            
            // Save the task information
            if let task = task {
                // Save session type
                if task is AVAssetDownloadTask {
                    entry["session"] = "avasset"
                } else { entry["session"] = "common" }
                
                // Save taskIdentifier
                entry["taskIdentifier"] = task.taskIdentifier
            }
            
            // Save resume data
            if let resumeData = resumeData {
                entry["resumeData"] = resumeData
            }
            
            // Persist the data to parent
            parent.persistedContentList[identifier] = entry
        }
    }
    
    /// Updates the persisted tasks
    func taskPropertyDidChange(current: URLSessionTask?, previous: URLSessionTask?) {
        if let current = current, current != previous {
            parent.contentDidCreateNewTask(current, fromContent: self)
        }
        
        // Save the new task identifier to the persisted property list
        persistedLocalProperties()
    }
}

// MARK: - Background download events handling
extension AppDelegate {
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        // Stores completion handler
        OfflineContentManager.shared.backgroundSessionCompletionHandler = completionHandler
    }
}
