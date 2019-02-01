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

import Foundation

/// Representing the state of the object
enum OfflineState {
    case ready
    case preservationInitialed
    case preserving(Float)
    case error(Error)
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
        if case .preserved = state {
            // Check if the content is available and readable
            guard let url = preservedContentURL,
                FileManager.default.fileExists(atPath: url.path) else {
                state = .ready
                return
            }
        }
    }
    
    /// Delete the preserved offline content
    func delete() {
        if let url = preservedContentURL {
            do {
                try FileManager.default.removeItem(at: url)
            } catch { Log.error(error) }
        }
    }
    
    /// Cancel preservation
    func cancel() {
        guard case .preserving = state else { return }
        task?.cancel()
        task = nil
        state = .ready
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
            case "ready": self = .ready; return
            case "preserving":
                if let progress = dict["progress"] as? Float {
                    self = .preserving(progress)
                }
            case "preserved": self = .preserved
            default: break
            }
        }
    }
    
    var export: [String: Any] {
        var dict = [String: Any]()
        switch self {
        case .ready, .error, .preservationInitialed: dict["type"] = "ready"
        case .preserving(let progress):
            dict["type"] = "preserving"
            dict["progress"] = progress
        case .preserved: dict["type"] = "preserved"
        }
        return dict
    }
}
