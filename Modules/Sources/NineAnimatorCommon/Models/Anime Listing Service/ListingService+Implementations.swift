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

// ListingAnimeReference+Codable
public extension ListingAnimeReference {
    internal enum Keys: CodingKey {
        case service
        case identifier
        case state
        case name
        case artwork
//        case userInfo
    }
    
    init(_ parent: ListingService,
         name: String,
         identifier: String,
         state: ListingAnimeTrackingState? = nil,
         artwork: URL? = nil,
         userInfo: [String: Any] = [:]) {
        self.parentService = parent
        self.name = name
        self.uniqueIdentifier = identifier
        self.artwork = artwork
        self.userInfo = userInfo
        self.state = state
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        // Decode parent service
        let serviceName = try container.decode(String.self, forKey: .service)
        guard let service = NineAnimator.default.service(with: serviceName) else {
            throw NineAnimatorError.decodeError
        }
        parentService = service
        
        // Decode basic info
        uniqueIdentifier = try container.decode(String.self, forKey: .identifier)
        artwork = try container.decodeIfPresent(URL.self, forKey: .artwork)
        name = try container.decode(String.self, forKey: .name)
        state = try container.decodeIfPresent(ListingAnimeTrackingState.self, forKey: .state)
        
        // userInfo will not be decoded
        userInfo = [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        
        // Encode basic info; userInfo will not be encoded
        try container.encode(parentService.name, forKey: .service)
        try container.encode(uniqueIdentifier, forKey: .identifier)
        try container.encodeIfPresent(artwork, forKey: .artwork)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(state, forKey: .state)
    }
}

// ListingAnimeName+CustomStringConvertible
public extension ListingAnimeName {
    var description: String { self.default }
    
    func proximity(to anime: AnimeLink) -> Double {
        [ native, english, romaji, `default` ].reduce(0.0) {
            max($0, $1.proximity(to: anime.title, caseSensitive: false))
        }
    }
}

// ListingAnimeReference+Hashable
public extension ListingAnimeReference {
    func hash(into hasher: inout Hasher) {
        hasher.combine(parentService.name)
        hasher.combine(uniqueIdentifier)
    }
    
    static func == (_ lhs: ListingAnimeReference, _ rhs: ListingAnimeReference) -> Bool {
        (lhs.parentService.name == rhs.parentService.name) &&
            (lhs.uniqueIdentifier == rhs.uniqueIdentifier)
    }
}

public extension ListingAnimeStatistics {
    var meanScore: Double {
        let sum = ratingsDistribution.reduce((0, 0)) { ($0.0 + ($1.key * $1.value), $0.1 + $1.value) }
        guard sum.1 > 0 else { return 0 }
        return sum.0 / sum.1
    }
}

public extension ListingService {
    func deauthenticate() {
        Log.error("[ListingService] Concrete classes did not inherit the deauthenticate() method. Listing Service's user will not be deauthenticated.")
    }
}
