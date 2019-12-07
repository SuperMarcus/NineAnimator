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
        get {
            return _freezer.typedValue(
                forKey: Keys.autoRestartInterruptedDownloadTasks,
                default: true
            )
        }
        set { _freezer.set(newValue, forKey: Keys.autoRestartInterruptedDownloadTasks) }
    }
    
    /// Preventing the system from purging downloaded episodes by marking each episodes as important
    var preventAVAssetPurge: Bool {
        get {
            return _freezer.typedValue(
                forKey: Keys.preventAVAssetPurge,
                default: false
            )
        }
        set { _freezer.set(newValue, forKey: Keys.preventAVAssetPurge) }
    }
    
    /// If NineAnimator should send a user notification when a download completes
    var sendDownloadsNotifications: Bool {
        get {
            return _freezer.typedValue(
                forKey: Keys.sendDownloadNotifications,
                default: false
            )
        }
        set { _freezer.set(newValue, forKey: Keys.sendDownloadNotifications) }
    }
    
    /// The name of the current theme
    var theme: String {
        get { return _freezer.string(forKey: Keys.theme) ?? "light" }
        set { _freezer.set(newValue, forKey: Keys.theme) }
    }
    
    /// Adjust brightness based on current screen brightness
    var dynamicAppearance: Bool {
        get { return _freezer.bool(forKey: Keys.brightnessBasedTheme) }
        set { _freezer.set(newValue, forKey: Keys.brightnessBasedTheme) }
    }
    
    /// Show what streaming services that the new episode of a subscribed anime
    /// is available on in an notification.
    var notificationShowStreams: Bool {
        get { return _freezer.bool(forKey: Keys.notificationShowStream) }
        set { _freezer.set(newValue, forKey: Keys.notificationShowStream) }
    }
    
    /// Allow NineAnimator to solve WAF challenges (e.g. Cloudflare's I'm Under
    /// Attack verification) automatically.
    ///
    /// This was disabled by default as of 1.1b2 since the WAF resolver is unstable
    /// and usually takes a long time to fallback to manual authentication.
    /// Until the challenge resolver has stablized, there will be no preferences
    /// menu option to enable this functionality.
    ///
    /// Re-enabled on 1.1b8 thanks to [Awsomedude](https://github.com/Awsomedude)
    var solveFirewallChalleges: Bool {
        get { return _freezer.value(forKey: Keys.sourceSolveChallenges) as? Bool ?? true }
        set { _freezer.set(newValue, forKey: Keys.sourceSolveChallenges) }
    }
    
    /// Allow sources to provide NSFW contents
    var allowNSFWContent: Bool {
        get { return _freezer.bool(forKey: Keys.allowNSFWContent) }
        set { _freezer.set(newValue, forKey: Keys.allowNSFWContent) }
    }
    
    /// Silence warnings about a specific purpose of a server
    func silenceUnrecommendedWarnings(forServer server: Anime.ServerIdentifier, ofPurpose purpose: VideoProviderParser.Purpose) {
        var listOfSilencedPurposes = _silencedUnrecommendedServerPurposes[server] ?? []
        listOfSilencedPurposes.insert(purpose)
        _silencedUnrecommendedServerPurposes[server] = listOfSilencedPurposes
    }
    
    /// Check if a warning realted to a specific purpose on a server should be silenced
    func shouldSilenceUnrecommendedWarnings(forServer server: Anime.ServerIdentifier, ofPurpose purpose: VideoProviderParser.Purpose) -> Bool {
        return _silencedUnrecommendedServerPurposes[server]?.contains(purpose) == true
    }
}
