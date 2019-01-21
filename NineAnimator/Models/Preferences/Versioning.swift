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

/// Representing a configuration change
struct ConfigurationChange {
    enum Category: String, Codable {
        /// Inserting a value to the front of the list
        case listInsertion
        
        /// Adding a value to the back of the list
        case listAddition
        
        /// Deleting a value from the list
        case listDeletion
        
        /// Updating the value of a non-list element
        case update
    }
    
    struct VersionedItem: Codable, Equatable {
        let name: String
        let key: PartialKeyPath<NineAnimatorUser>
    }
    
    struct ChangedValue: Codable {
        let value: Codable?
    }
    
    let timestamp: TimeInterval
    
    let category: Category
    
    let key: VersionedItem
}

// MARK: - ConfigurationChange.VersionedItem: Codable and constants
extension ConfigurationChange.VersionedItem {
    static let history = ConfigurationChange.VersionedItem(name: "history", key: \NineAnimatorUser.recentAnimes)
    
    static let playbackProgress = ConfigurationChange.VersionedItem(name: "playbackProgress", key: \NineAnimatorUser.persistedProgresses)
    
    static let subscriptions = ConfigurationChange.VersionedItem(name: "subscriptions", key: \NineAnimatorUser.watchedAnimes)
    
    static let lastWatched = ConfigurationChange.VersionedItem(name: "lastWatched", key: \NineAnimatorUser.lastEpisode)
    
    var requiredCapabilities: SyncingServiceCapabilities {
        switch self {
        case .history: return [ .history ]
        case .playbackProgress: return [ .playbackProgress ]
        case .subscriptions: return [ .subscriptions ]
        case .lastWatched: return [ .lastWatched ]
        default: return []
        }
    }
    
    fileprivate enum VersionedItemCodingKeys: CodingKey {
        case name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VersionedItemCodingKeys.self)
        let Static = type(of: self)
        
        name = try container.decode(String.self, forKey: .name)
        
        switch name {
        case Static.history.name: key = Static.history.key
        case Static.playbackProgress.name: key = Static.playbackProgress.key
        case Static.subscriptions.name: key = Static.subscriptions.key
        case Static.lastWatched.name: key = Static.lastWatched.key
        default: throw NineAnimatorError.decodeError
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: VersionedItemCodingKeys.self)
        try container.encode(name, forKey: .name)
    }
    
    static func == (_ lhs: ConfigurationChange.VersionedItem, _ rhs: ConfigurationChange.VersionedItem) -> Bool {
        return lhs.name == rhs.name
    }
}

extension ConfigurationChange.ChangedValue {
    fileprivate enum ChangedValueCodingKeys: CodingKey {
        case type
        case value
    }
    
    fileprivate enum Types: String, Codable {
        case none = "com.marcuszhou.NineAnimator.type.nil"
        case float = "com.marcuszhou.NineAnimator.type.float"
        case animeLink = "com.marcuszhou.NineAnimator.type.anime"
        case episodeLink = "com.marcuszhou.NineAnimator.type.episode"
        case animeLinkList = "com.marcuszhou.NineAnime.type.list.anime"
        case episodeLinkList = "com.marcuszhou.NineAnime.type.list.episode"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ChangedValueCodingKeys.self)
        
        switch try container.decode(Types.self, forKey: .type) {
        case .float: value = try container.decode(Float.self, forKey: .value)
        case .animeLink: value = try container.decode(AnimeLink.self, forKey: .value)
        case .episodeLink: value = try container.decode(EpisodeLink.self, forKey: .value)
        case .animeLinkList: value = try container.decode([AnimeLink].self, forKey: .value)
        case .episodeLinkList: value = try container.decode([EpisodeLink].self, forKey: .value)
        case .none: value = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ChangedValueCodingKeys.self)
        
        if let value = value {
            switch value {
            case let value as Float:
                try container.encode(Types.float, forKey: .type)
                try container.encode(value, forKey: .value)
            case let value as AnimeLink:
                try container.encode(Types.animeLink, forKey: .type)
                try container.encode(value, forKey: .value)
            case let value as EpisodeLink:
                try container.encode(Types.episodeLink, forKey: .type)
                try container.encode(value, forKey: .value)
            case let value as [AnimeLink]:
                try container.encode(Types.animeLinkList, forKey: .type)
                try container.encode(value, forKey: .value)
            case let value as [EpisodeLink]:
                try container.encode(Types.episodeLinkList, forKey: .type)
                try container.encode(value, forKey: .value)
            default: Log.error("Trying to code unknown type - %@", type(of: value))
            }
        } else { try container.encode(Types.none, forKey: .type) }
    }
}
