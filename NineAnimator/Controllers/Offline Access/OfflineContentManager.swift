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
    
    // A user defaults suit for indexing & handling offline contents
    fileprivate let offlineContentProperties = UserDefaults(suiteName: "com.marcuszhou.NineAnimator.OfflineContents")!
    
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
    
    private lazy var registeredContentTypes: [String: ([String: Any], OfflineState) -> OfflineContent?] = {
        var typeRegistry = [String: ([String: Any], OfflineState) -> OfflineContent?]()
        
        typeRegistry["OfflineEpisodeContent"] = {
            OfflineEpisodeContent(self, from: $0, initialState: $1)
        }
        
        return typeRegistry
    }()
    
    private var persistedContentPool: [OfflineContent] {
        return offlineContentProperties.dictionaryRepresentation()
            .compactMap {
                item -> OfflineContent? in
                guard let dict = item.value as? [String: Any] else { return nil }
                guard let type = dict["type"] as? String,
                    let stateDict = dict["state"] as? [String: Any],
                    let properties = dict["properties"] as? [String: Any] else { return nil }
                
                var state = OfflineState(from: stateDict)
                var preservedUrl: URL?
                
                if case .preserved = state {
                    if let urlString = dict["path"] as? String,
                        let url = URL(string: urlString) {
                        preservedUrl = url
                    } else { state = .ready }
                }
                
                let content = registeredContentTypes[type]?(properties, state)
                content?.preservedContentURL = preservedUrl
                
                return content
            }
    }
    
    // An array to store references to contents
    private lazy var contentPool = persistedContentPool
    
    func content(for episodeLink: EpisodeLink) -> OfflineEpisodeContent {
        if let content = contentPool
            .compactMap({ $0 as? OfflineEpisodeContent })
            .first(where: { $0.episodeLink == episodeLink }) {
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
            content.persistOfflineState()
            // Call the background session completion handler
            backgroundSessionCompletionHandler?()
            backgroundSessionCompletionHandler = nil
        }
        
        let fs = FileManager.default
        let destinationUrl: URL
        
        // Move content to the download folder
        do {
            // Copy the content to the download folder
            let downloadFolder = try fs.url(
                for: .downloadsDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let illegalCharacters = CharacterSet(charactersIn: "/*:<>?%|")
            let newName = content.suggestName(for: location)
                .components(separatedBy: illegalCharacters)
                .joined(separator: "_")
            let pathExtension = downloadTask.response?.suggestedFilename?.split(separator: ".").last ?? "bin"
            destinationUrl = downloadFolder.appendingPathComponent("\(newName).\(pathExtension)")
            
            if (try? destinationUrl.checkResourceIsReachable()) == true {
                Log.error("Duplicated file detected, removing.")
                try fs.removeItem(at: destinationUrl)
            }
            
            // Move the item
            try fs.moveItem(at: location, to: destinationUrl)
        } catch {
            Log.error("Failed to rename the downloaded asset: %@", error)
            content._onCompletion(session, error: error)
            try? fs.removeItem(at: location) // Remove the item
            return
        }
        
        // Call the internal completion handler
        content._onCompletion(session, location: destinationUrl)
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
            content.persistOfflineState()
            // Call the background session completion handler
            backgroundSessionCompletionHandler?()
            backgroundSessionCompletionHandler = nil
        }
        
        content._onCompletion(session, location: location)
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

// MARK: - Exposed APIs to offline content from parent
extension OfflineContent {
    var assetDownloadingSession: AVAssetDownloadURLSession { return parent.sharedAssetSession }
    
    var downloadingSession: URLSession { return parent.sharedSession }
    
    var persistedProperties: [String: Any] {
        get {
            if !identifier.isEmpty, let store = parent.offlineContentProperties
                .dictionary(forKey: identifier)?["properties"] as? [String: Any] {
                return store
            } else { return [:] }
        }
        set {
            if !identifier.isEmpty {
                var entry = parent.offlineContentProperties.dictionary(forKey: identifier) ?? [:]
                entry["type"] = String(describing: type(of: self))
                entry["properties"] = newValue
                entry["state"] = state.export
                
                if let url = preservedContentURL { entry["path"] = url.absoluteString }
                
                parent.offlineContentProperties.set(entry, forKey: identifier)
            }
        }
    }
    
    func persistOfflineState() {
        let properties = persistedProperties
        persistedProperties = properties
    }
    
    fileprivate func _onCompletion(_ session: URLSession, location: URL) {
        preservedContentURL = location
        state = .preserved
        onCompletion(with: location)
    }
    
    fileprivate func _onCompletion(_ session: URLSession, error: Error) {
        onCompletion(with: error)
        state = .error(error)
    }
    
    fileprivate func _onProgress(_ session: URLSession, progress: Double) {
        state = .preserving(Float(progress))
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
