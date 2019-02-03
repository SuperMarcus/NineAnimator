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
    
    fileprivate var backgroundSessionCompletionHandler: (() -> Void)?
    
    fileprivate var persistedContentIndexURL: URL {
        return persistentDirectory
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
                    .write(to: persistedContentIndexURL)
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
            Log.error("Cannot obtain persistent directory: %@. This is an fatal error and the app cannot continue.", error)
            // Should I handle this error?
            fatalError("Cannot obtain OfflineContents directory")
        }
    }
    
    /// User home directory, for `AVAssetDownloadURLSession` downloaded contents
    fileprivate var homeDirectory: URL {
        return URL(fileURLWithPath: NSHomeDirectory())
    }
    
    private lazy var registeredContentTypes: [String: ([String: Any], OfflineState) -> OfflineContent?] = {
        var typeRegistry = [String: ([String: Any], OfflineState) -> OfflineContent?]()
        
        typeRegistry["OfflineEpisodeContent"] = {
            OfflineEpisodeContent(self, from: $0, initialState: $1)
        }
        
        return typeRegistry
    }()
    
    // An array to store references to contents
    private lazy var contentPool = persistedContentPool
    
    /// Retrieve a list of preserved contents
    var preservedContents: [OfflineContent] {
        return contentPool.filter {
            $0.updateResourceAvailability()
            if case .preserved = $0.state { return true }
            return false
        }
    }
    
    /// Retrieve a list of preserved or preserving contents
    var statefulContents: [OfflineContent] {
        return contentPool.filter {
            if case .preserving = $0.state { return true }
            if case .preservationInitiated = $0.state { return true }
            $0.updateResourceAvailability()
            if case .preserved = $0.state { return true }
            return false
        }
    }
    
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
        return content(for: episodeLink).state
    }
    
    /// Start preserving the episode
    func initiatePreservation(for episodeLink: EpisodeLink) {
        content(for: episodeLink).preserve()
    }
    
    /// Cancel the preservation (if in progress) for episode
    func cancelPreservation(for episodeLink: EpisodeLink) {
        content(for: episodeLink).cancel()
    }
}

// MARK: - URLSessionDownloadDelegate
extension OfflineContentManager {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard session == sharedSession, let content = content(for: downloadTask) else {
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
                throw NineAnimatorError.providerError("Cannot retrive url when resource identifier has been set")
            }
            
            if (try? destinationUrl.checkResourceIsReachable()) == true {
                Log.error("Duplicated file detected, removing.")
                try fs.removeItem(at: destinationUrl)
            }
            
            // Move the item
            try fs.moveItem(at: location, to: destinationUrl)
            
            // Set the resource to be excluded from backups
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try destinationUrl.setResourceValues(resourceValues)
            
            // Call the internal completion handler
            content._onCompletion(session)
        } catch {
            Log.error("Failed to rename the downloaded asset: %@", error)
            content.persistentResourceIdentifier = nil
            content._onCompletion(session, error: error)
            try? fs.removeItem(at: location) // Remove the item
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard session == sharedSession, let content = content(for: task), let error = error else {
            return
        }
        
        content._onCompletion(session, error: error)
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard session == sharedSession, let content = content(for: downloadTask) else {
            return
        }
        
        let progress = (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) ?
            0.9 : Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        content._onProgress(session, progress: progress)
    }
    
    private func content(for task: URLSessionTask) -> OfflineContent? {
        return contentPool.first { $0.task == task }
    }
}

// MARK: - AVAssetDownloadDelegate
extension OfflineContentManager {
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard session == sharedAssetSession, let content = content(for: assetDownloadTask) else {
            return
        }
        
        defer {
            content.persistedLocalProperties()
            // Call the background session completion handler
            backgroundSessionCompletionHandler?()
            backgroundSessionCompletionHandler = nil
        }
        
        // Set resource identifier
        content.persistentResourceIdentifier = (location.relativePath, "home")
        content._onCompletion(session)
    }
    
    func urlSession(_ session: URLSession,
                    assetDownloadTask: AVAssetDownloadTask,
                    didLoad timeRange: CMTimeRange,
                    totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                    timeRangeExpectedToLoad: CMTimeRange) {
        guard session == sharedAssetSession, let content = content(for: assetDownloadTask) else {
            return
        }
        
        let progress = Double(timeRange.end.value) / Double(timeRangeExpectedToLoad.end.value)
        content._onProgress(session, progress: progress)
    }
}

// MARK: - Navigating through contents
extension OfflineContentManager {
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
        return statefulContents
            .compactMap { $0 as? OfflineEpisodeContent }
            .filter { $0.episodeLink.parent == anime }
    }
}

// MARK: - Managing persisted assets
extension OfflineContentManager {
    /// Parse OfflineContent from file system
    private var persistedContentPool: [OfflineContent] {
        return persistedContentList.compactMap {
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
                
                Log.info("A preserved resource is unrestorable. Resetting to ready state.")
                
                // If the url cannot be restored, reset state to ready
                content.persistentResourceIdentifier = nil
                content.state = .ready
            }
            
            return content
        }.filter {
            // Only return contents that are not 'ready' nor 'error'
            switch $0.state {
            case .error, .ready: return false
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
}

// MARK: - Exposed APIs to offline content from parent
extension OfflineContent {
    var assetDownloadingSession: AVAssetDownloadURLSession { return parent.sharedAssetSession }
    
    var downloadingSession: URLSession { return parent.sharedSession }
    
    /// The url on the file system to where the offline content is stored
    ///
    /// Set by the manager
    var preservedContentURL: URL? {
        guard let resourceIdentifier = self.persistentResourceIdentifier else {
            return nil
        }
        
        let path = resourceIdentifier.relativePath
        switch resourceIdentifier.relativeTo {
        case "home": return parent.homeDirectory.appendingPathComponent(path)
        case "persist": return parent.persistentDirectory.appendingPathComponent(path)
        default: return nil
        }
    }
    
    fileprivate func _onCompletion(_ session: URLSession) {
        guard let location = preservedContentURL else {
            persistentResourceIdentifier = nil
            Log.error("Location cannot be retrived after resource identifier has been set")
            state = .error(NineAnimatorError.providerError("Location cannot be identified"))
            return
        }
        
        guard (try? location.checkResourceIsReachable()) == true else {
            persistentResourceIdentifier = nil
            Log.error("Downloaded resource is unreachable")
            state = .error(NineAnimatorError.providerError("Unreachable offline content"))
            return
        }
        
        Log.info("Content persisted to %@", location.absoluteString)
        
        // Update state and call completion handler
        datePreserved = Date()
        state = .preserved
        onCompletion(with: location)
    }
    
    fileprivate func _onCompletion(_ session: URLSession, error: Error) {
        Log.info("Content persistence finished with error: %@", error)
        onCompletion(with: error)
        state = .error(error)
    }
    
    fileprivate func _onProgress(_ session: URLSession, progress: Double) {
        state = .preserving(Float(progress))
    }
    
    // Encode and stores the persistent information for this content on the file system
    func persistedLocalProperties() {
        switch state {
        case .error, .ready:
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
            
            parent.persistedContentList[identifier] = entry
        }
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
