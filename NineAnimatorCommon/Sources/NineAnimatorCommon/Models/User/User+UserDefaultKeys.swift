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

public extension NineAnimatorUser {
    /// Default keys of NineAnimator
    enum Keys {
        static var version: String { "com.marcuszhou.nineanimator.version" }
        static var recentAnimeList: String { "anime.recent" }
        static var detectClipboardAnimeLinks: String { "anime.links.detect" }
        static var subscribedAnimeList: String { "anime.subscribed" }
        static var allowNSFWContent: String { "anime.content.nsfw" }
        static var animeInformationSource: String { "anime.details.source" }
        static var autoRestartInterruptedDownloadTasks: String { "episode.download.autorestart" }
        static var preventAVAssetPurge: String { "episode.download.preventPurge" }
        static var sendDownloadNotifications: String { "episode.download.sendDownloadNotifications" }
        static var downloadEpisodesInBackground: String { "episode.download.inBackground" }
        static var recentEpisode: String { "episode.recent" }
        static var recentSource: String { "source.recent" }
        static var searchHistory: String { "history.search" }
        static var sourceSolveChallenges: String { "source.challengeSolver" }
        static var sourceExplicitEnabled: String { "source.explicit.allowed" }
        static var recentServer: String { "server.recent" }
        static var persistedProgresses: String { "episode.progress" }
        static var episodeListingOrder: String { "episode.listing.order" }
        static var episodeDetails: String { "episode.details" }
        static var backgroundPlayback: String { "playback.background" }
        static var pictureInPicturePlayback: String { "playback.pip" }
        static var playbackFallbackToBrowser: String { "playback.browser" }
        static var notificationShowStream: String { "notification.showStreams" }
        static var homeExternalOnly: String { "home.externalOnly" }
        static var homeUUIDStart: String { "home.actionset.uuid.start" }
        static var homeUUIDEnd: String { "home.actionset.uuid.end" }
        static var theme: String { "interface.theme" }
        static var brightnessBasedTheme: String { "interface.brightnessBasedTheme" }
        static var discoveredAppIcons: String { "interface.discoveredIcons" }
        static var richPresenceEnable: String { "presence.enable" }
        static var richPresenceShowAnimeName: String { "presence.animeTitle" }
        static var optOutAnalytics: String { "analytics.optOut" }
        static var crashReporterShouldRedactLogs: String { "crashReporter.log.redact" }
        
        // Watching anime episodes persist filename
        static var watchedAnimesFileName: String { "com.marcuszhou.NineAnimator.anime.watching.plist" }
    }
    
    /// A property wrapper for an entry in the UserDefaults
    @propertyWrapper
    struct Entry<ValueType> {
        private let key: String
        private unowned var store: UserDefaults
        private let defaultValue: ValueType
        
        public var wrappedValue: ValueType {
            get {
                if let value = store.value(forKey: key) as? ValueType {
                    return value
                } else { return defaultValue }
            }
            set { store.set(newValue, forKey: key) }
        }
        
        public init(_ key: String, store: UserDefaults, default: ValueType) {
            self.key = key
            self.store = store
            self.defaultValue = `default`
        }
    }
}
