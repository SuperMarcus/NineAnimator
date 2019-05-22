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
            
            // Fire notification
            NotificationCenter.default.post(name: .offlineAccessStateDidUpdate, object: self)
        }
    }
    
    var parent: OfflineContentManager
    
    var identifier: String { return "" }
    
    // The provisioned downloading task of this OfflineContent
    var task: URLSessionTask?
    
    /// Access the date that the content is preserved
    var datePreserved: Date?
    
    /// Properties in this dictionary are persisted across launches
    var persistedProperties: [String: Any] {
        // Save local properties when updated
        didSet { persistedLocalProperties() }
    }
    
    /// Used to recreate the persistent url
    ///
    /// Ideally no one besides the manager should access this property.
    /// Subclasses should use the `preservedContentURL` property to
    /// access the content.
    var persistentResourceIdentifier: (relativePath: String, relativeTo: String)?
    
    /// The data to resume the download task
    var resumeData: Data?
    
    init(_ manager: OfflineContentManager, initialState: OfflineState) {
        state = initialState
        parent = manager
        persistedProperties = [:]
        super.init()
    }
    
    required init?(_ manager: OfflineContentManager, from properties: [String: Any], initialState: OfflineState) {
        state = initialState
        parent = manager
        persistedProperties = properties
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
    func onCompletion(with url: URL) { }
    
    /// Called when an error from the downloading task is caught
    func onCompletion(with error: Error) { }
    
    /// Initiate preservation
    func preserve() { }
    
    /// Checks if the content still exists on file system and
    /// update the states accordingly.
    func updateResourceAvailability() {
        func fallbackToReady() {
            resumeData = nil
            task?.cancel()
            task = nil
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
    func delete() {
        // Cancel the task first
        cancel()
        
        // If the file exists, remove it
        if let url = preservedContentURL {
            do {
                try FileManager.default.removeItem(at: url)
            } catch { Log.error(error) }
        }
        
        // Update state to ready
        state = .ready
    }
    
    /// Cancel preservation
    func cancel() {
        guard case .preserving = state else { return }
        task?.cancel()
        task = nil
        state = .ready
    }
    
    /// Resume the interruption if possible
    func resumeInterruption() {
        // Only resume a task that is suspended or errored
        switch state {
        case .interrupted, .error: break
        default:
            Log.error("Trying to resume a task that is neither suspended nor errored. Aborting.")
            return
        }
        
        // Resume the task
        if let task = task {
            if case .suspended = task.state {
                Log.info("Trying to resume a suspended download task")
                task.resume()
                state = .preservationInitiated
            } else { state = .error(NineAnimatorError.providerError("Task is not resumable")) }
            return
        } else if let resumeData = resumeData {
            Log.info("Trying to resume a download task with resume data")
            
            // Resuming with resume data is only possible with common session
            if persistedDownloadSessionType == "common" {
                task = downloadingSession.downloadTask(withResumeData: resumeData)
                state = .preservationInitiated
                return
            }
            
            Log.error("Cannot resume task. No supported session found, only %@", persistedDownloadSessionType ?? "Unknown Type (nil)")
        }
        
        // Update state to error
        state = .error(NineAnimatorError.providerError("Cannot resume downloading task"))
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

extension OfflineState {
    init(from dict: [String: Any]) {
        self = .ready
        if let type = dict["type"] as? String {
            switch type {
            case "ready": self = .ready
            // The following states are all handled as interrupted
            case "error", "interrupted", "preserving": self = .interrupted
            case "preserved": self = .preserved
            default: break
            }
        }
    }
    
    var export: [String: Any] {
        var dict = [String: Any]()
        switch self {
        case .ready, .preservationInitiated: dict["type"] = "ready"
        case .preserving(let progress):
            dict["type"] = "preserving"
            dict["progress"] = progress
        case .interrupted, .error: dict["type"] = "interrupted"
        case .preserved: dict["type"] = "preserved"
        }
        return dict
    }
}
