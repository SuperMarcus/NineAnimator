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

/**
 Representing the capabilites of the syncing service
 */
struct SyncingServiceCapabilities: OptionSet {
    let rawValue: Int
    
    /// Can sync recently watched anime
    static let history = SyncingServiceCapabilities(rawValue: 1 << 0)
    
    /// Can sync playback progresses in percentage (0.0 - 1.0)
    static let playbackProgress = SyncingServiceCapabilities(rawValue: 1 << 1)
    
    /// Can sync subscribed anime
    static let subscriptions = SyncingServiceCapabilities(rawValue: 1 << 2)
    
    /// Can sync last watched anime
    static let lastWatched = SyncingServiceCapabilities(rawValue: 1 << 3)
}

/**
 Attach to NineAnimatorUser to facilitate user profile syncing.
 
 All the cloud syncing services should be implemented under this protocol
 and attach to NineAnimatorUser
 */
protocol SyncingService: AnyObject {
    var capabilities: SyncingServiceCapabilities { get }
    
    var delegate: NineAnimatorUser? { get set }
    
    /// Perform a local first synchronization for playback history
    func synchronize(history: [AnimeLink]) -> NineAnimatorAsyncTask?
    
    /// Perform a local first synchronization for playback progresses
    ///
    /// - Parameter playbackProgress: A list of updated episode identifiers and their new progresses
    func synchronize(playbackProgress: [String: Float]) -> NineAnimatorAsyncTask?
    
    /// Perform a local first synchronization for subscriptions
    func synchronize(additionalSubscriptions: [AnimeLink]) -> NineAnimatorAsyncTask?
    
    /// Perform a local first synchronization for last watched anime
    func synchronize(lastWatched: AnimeLink) -> NineAnimatorAsyncTask?
    
    /// Perform a remote-first merge synchronization
    func synchronize() -> NineAnimatorAsyncTask?
}

// Stubs
extension SyncingService {
    func synchronize(history: [AnimeLink]) -> NineAnimatorAsyncTask? { return nil }
    
    func synchronize(playbackProgress: [String: Float]) -> NineAnimatorAsyncTask? { return nil }
    
    func synchronize(subscriptions: [AnimeLink]) -> NineAnimatorAsyncTask? { return nil }
    
    func synchronize(lastWatched: AnimeLink) -> NineAnimatorAsyncTask? { return nil }
}
