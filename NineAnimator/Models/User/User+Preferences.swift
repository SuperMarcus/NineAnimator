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

// MARK: - Preferences
extension NineAnimatorUser {
    enum EpisodeListingOrder: String {
        /// List from the first episode to the last
        case ordered
        
        /// List from the latest episode to the initial episode
        case reversed
        
        init(from value: Any?) {
            guard let value = value as? String else { self = .ordered; return }
            guard let order = EpisodeListingOrder(rawValue: value) else { self = .ordered; return }
            self = order
        }
    }
    
    /// The listing order of episodes in an anime
    var episodeListingOrder: EpisodeListingOrder {
        get { return EpisodeListingOrder(from: _freezer.string(forKey: Keys.episodeListingOrder)) }
        set {
            _freezer.set(newValue.rawValue, forKey: Keys.episodeListingOrder)
        }
    }
    
    /// Show the synopsis of each episode (if available)
    var showEpisodeDetails: Bool {
        get { return (_freezer.value(forKey: Keys.episodeDetails) as? Bool) ?? true }
        set { _freezer.set(newValue, forKey: Keys.episodeDetails) }
    }
    
    /// Continues to play video even when the app goes into background
    ///
    /// This prevents `AVPlayerViewController` from pausing the video when the
    /// app enters background
    var allowBackgroundPlayback: Bool {
        get { return _freezer.bool(forKey: Keys.backgroundPlayback) }
        set {
            _freezer.set(newValue, forKey: Keys.backgroundPlayback)
        }
    }
    
    /// Allow Picture in Picture playback
    ///
    /// This setting is only available on iPads
    var allowPictureInPicturePlayback: Bool {
        get { return _freezer.value(forKey: Keys.pictureInPicturePlayback) as? Bool ?? true }
        set {
            _freezer.set(newValue, forKey: Keys.pictureInPicturePlayback)
        }
    }
    
    /// Detects any possible links to anime when the app becomes active
    var detectsPasteboardLinks: Bool {
        get { return _freezer.bool(forKey: Keys.detectClipboardAnimeLinks) }
        set { _freezer.set(newValue, forKey: Keys.detectClipboardAnimeLinks) }
    }
    
    /// Attempt to resume downloading tasks from URLSessions after the app launches
    var autoRestartInterruptedDownloads: Bool {
        get { return _freezer.bool(forKey: Keys.autoRestartInterruptedDownloadTasks) }
        set { _freezer.set(newValue, forKey: Keys.autoRestartInterruptedDownloadTasks) }
    }
    
    /// The name of the current theme
    var theme: String {
        get { return _freezer.string(forKey: Keys.theme) ?? "light" }
        set { _freezer.set(newValue, forKey: Keys.theme) }
    }
    
    /// Adjust brightness based on current screen brightness
    var brightnessBasedTheme: Bool {
        get { return _freezer.bool(forKey: Keys.brightnessBasedTheme) }
        set { _freezer.set(newValue, forKey: Keys.brightnessBasedTheme) }
    }
    
    /// Show what streaming services that the new episode of a subscribed anime
    /// is available on in an notification.
    var notificationShowStreams: Bool {
        get { return _freezer.bool(forKey: Keys.notificationShowStream) }
        set { _freezer.set(newValue, forKey: Keys.notificationShowStream) }
    }
}
