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

import Foundation

public extension Notification.Name {
    /**
    Fired when the playback progress has been updated in the NineAnimatorUser
     
     ## UserInfo
     - Provides the episodeLink and it's updated playback progress:
     - "episodeLink": `EpisodeLink`,
     - "updatedProgress": `Float`
     
    */
    static let playbackProgressDidUpdate =
        Notification.Name("com.marcuszhou.nineanimator.playbackProgressDidUpdate")
    
    /**
    Fired when the playback progress has been updated for multiple episodes in the NineAnimatorUser
     
     ## UserInfo
     - Provides array of episodeLink's and it's updated playback progress:
     - "episodeLinks": `[EpisodeLink]`,
     - "updatedProgress": `Float`
     
    */
    static let batchPlaybackProgressDidUpdate =
        Notification.Name("com.marcuszhou.nineanimator.batchPlaybackProgressDidUpdate")
    
    /// Fired when the video is starting to play
    ///
    /// ## Where its posted
    /// - After `NativePlayerController.play(media: PlaybackMedia)` presented the player
    /// - `GoogleCastMediaPlaybackViewController.playback(didStart media: CastMedia)`
    static let playbackDidStart =
        Notification.Name("com.marcuszhou.nineanimator.playbackDidStart")
    
    /**
     Fired within the last 15 seconds of video playback
     
     ## Where its posted
     
     - Checked in `NativePlayerController.persistProgress()`
     - Checked in `GoogleCastMediaPlaybackViewController.playback(update media: CastMedia, mediaStatus status: CastMediaStatus)`
     */
    static let playbackWillEnd =
        Notification.Name("com.marcuszhou.nineanimator.playbackWillEnd")
    
    /**
     Fired after the playback has ended
     
     ## Where its posted
     
     - `GoogleCastMediaPlaybackViewController.playback(didEnd media: CastMedia)`
     - `NativePlayerController.onPlayerRateChange`
     - `NativePlayerController.reset`
     */
    static let playbackDidEnd =
        Notification.Name("com.marcuszhou.nineanimator.playbackWillEnd")
    
    /**
     Fired when the video is starting to play on an external display
     
     ## Where its posted
     
     - When `NativePlayerController.onPlayerExternalPlaybackChange(player _: AVPlayer, change _: NSKeyValueObservedChange<Bool>)` detects external playback is active
     - `GoogleCastMediaPlaybackViewController.playback(didStart media: CastMedia)`
     */
    static let externalPlaybackDidStart =
        Notification.Name("com.marcuszhou.nineanimator.externalPlaybackDidStart")
    
    /**
     Fired within the last 15 seconds of external playback
     
     ## Where its posted
     
     - Fired after `playbackWillEnd` in `NativePlayerController.persistProgress()` if external playback is active
     - Checked in `GoogleCastMediaPlaybackViewController.playback(update media: CastMedia, mediaStatus status: CastMediaStatus)`
     */
    static let externalPlaybackWillEnd =
        Notification.Name("com.marcuszhou.nineanimator.externalPlaybackWillEnd")
    
    /**
     Fired when external playback stops
     
     This event might fire even if `externalPlaybackWillEnd` did not fire
     
     ## Where its posted
     
     - Fired when `NativePlayerController.onPlayerExternalPlaybackChange(player _: AVPlayer, change _: NSKeyValueObservedChange<Bool>)` detects external playback is not active anymore
     - `GoogleCastMediaPlaybackViewController.playback(didEnd media: CastMedia)`
     */
    static let externalPlaybackDidEnd =
        Notification.Name("com.marcuszhou.nineanimator.externalPlaybackDidEnd")
    
    /**
     Fired when the list of recommendation items are updated in a particular RecommendationSource
     
     ## Object
     - The object for this notification is the updated `RecommendationSource`
     */
    static let sourceDidUpdateRecommendation =
        Notification.Name("com.marcuszhou.nineanimator.sourceDidUpdateRecommendation")
    
    /// Fired when HomeKit status is updated
    static let homeDidUpdate =
        Notification.Name("com.marcuszhou.nineanimator.homeDidUpdate")
    
    /// Fired when the authroization status of the home manager has changed
    static let homeDidReceiveAuthroizationStatus =
        Notification.Name("com.marcuszhou.nineanimator.homeDidReceiveAuthroizationStatus")
    
    /// Fired when the offline access state is updated for an episode link
    static let offlineAccessStateDidUpdate =
        Notification.Name("com.marcuszhou.nineanimator.offlineAccessStateDidUpdate")
    
    /// Fired when the user's subscribed anime list has updated
    static let subscriptionsDidUpdate = Notification.Name("com.marcuszhou.nineanimator.subscriptionsDidUpdate")
    
    /// Fired when the rich presence has been updated.
    static let presenceControllerDidUpdatePresence =
        Notification.Name("com.marcuszhou.nineanimator.presenceControllerDidUpdatePresence")
    
    /// Fired when the RPC service connection state has changed
    static let presenceControllerConnectionStateDidUpdate =
        Notification.Name("com.marcuszhou.nineanimator.presenceControllerConnectionStateDidUpdate")
}
