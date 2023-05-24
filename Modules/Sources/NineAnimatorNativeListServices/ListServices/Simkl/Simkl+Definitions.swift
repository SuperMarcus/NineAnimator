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
import NineAnimatorCommon

//
// Simkl API Codable Definitions were written based on the simkl
// API documentations on Apiry
//

// MARK: - API Definitions
extension Simkl {
    /// An identifier entry included in the standard media objects
    struct SimklStdMediaIdentifierEntry: Codable {
        var simkl: Int
    }
    
    /// A standard media entry
    struct SimklStdMediaEntry: Codable {
        var title: String
        var ids: SimklStdMediaIdentifierEntry
        var poster: String?
    }
    
    /// Each entries in the syncing response
    struct SimklLibraryAnimeEntry: Codable {
        var show: SimklStdMediaEntry
        var status: String
    }
    
    /// Representing the response from syncing
    struct SimklLibrarySyncResponse: Codable {
        var anime: [SimklLibraryAnimeEntry]
    }
    
    /// Representing the entire response from querying the user settings
    struct UserSettingsResponse: Codable {
        var user: User
    }
    
    /// The identifier object included by the non-standard media responses
    struct SimklIdentifierEntry: Codable {
        var simkl_id: Int
    }
    
    /// Representing each media entry returned from searching the anime
    struct SimklMediaEntry: Codable {
        var title: String
        var ids: SimklIdentifierEntry
        var poster: String?
    }
    
    /// Each episode entry responded by querying the episodes of an anime
    struct SimklEpisodeEntry: Codable {
        var ids: SimklIdentifierEntry
        var episode: Int?
        var img: String?
        var type: String
        
        /// Convert to standard media object
        func toStandardEpisodeObject(_ watchDate: Date = .init()) -> SimklStdMediaEpisodeEntry {
            var std = SimklStdMediaEpisodeEntry(
                ids: .init(simkl: ids.simkl_id),
                watched_at: ""
            )
            std.lastWatchedDate = watchDate
            return std
        }
    }
    
    /// The type representing the response from querying the episodes
    /// of an anime
    typealias SimklAnimeEpisodesResponse = [SimklEpisodeEntry]
    
    /// A standard episode entry
    struct SimklStdMediaEpisodeEntry: Codable {
        var ids: SimklStdMediaIdentifierEntry
        var watched_at: String?
        
        var lastWatchedDate: Date? {
            get {
                if let w = watched_at { return Simkl.dateFormatter.date(from: w) }
                return nil
            }
            set {
                if let d = newValue { watched_at = Simkl.dateFormatter.string(from: d) }
            }
        }
    }
    
    /// Representing each entry in the get-last-activity response
    struct SimklActivitiesEntry: Codable {
        var all: String?
        var plantowatch: String?
        var watching: String?
        var completed: String?
        var notinteresting: String?
        var removed_from_list: String?
    }
    
    /// Representing the entirity of the get-last-activity response
    ///
    /// Reference: [get-last-activity](https://simkl.docs.apiary.io/#reference/sync/last-activities/get-last-activity)
    struct SimklActivitiesResponse: Codable {
        var all: String
        var tv_shows: SimklActivitiesEntry?
        var anime: SimklActivitiesEntry?
        var movies: SimklActivitiesEntry?
    }
    
    /// Standard DateFormatter for parsing and generating UTC time
    /// compatible with Simkl
    static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }
}

// MARK: - State conversion methods
extension Simkl {
    /// Converting the simkl status to NineAnimator's tracking state
    func simklToState(_ status: String) -> ListingAnimeTrackingState? {
        switch status {
        case "plantowatch": return .toWatch
        case "watching": return .watching
        case "completed": return .finished
        default: return nil
        }
    }
    
    /// Converting the NineAnimator's tracking state to simkl's status
    func stateToSimkl(_ state: ListingAnimeTrackingState) -> String {
        switch state {
        case .toWatch: return "plantowatch"
        case .watching: return "watching"
        case .finished: return "completed"
        }
    }
}

// MARK: - Persisted properties keys
extension Simkl {
    enum PersistedKeys {
        static let cachedCollections = "cached_collections"
        static let cacheLastUpdateDate = "cached_last_update"
        static let authorizationCode = "code"
        static let accessToken = "access_token"
    }
}
