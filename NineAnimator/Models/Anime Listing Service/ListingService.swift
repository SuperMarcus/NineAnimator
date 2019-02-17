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

/// Representing the tracking state of the listed anime
enum ListingAnimeTrackingState: String, Codable {
    case toWatch
    case watching
    case finished
}

/// Representing a listed anime
struct ListingAnimeInformation {
    let parentService: ListingService
}

/// Representing a reference that can be used to construct
/// `ListingAnimeInformation`
struct ListingAnimeReference: Codable {
    let parentService: ListingService
    
    /// An identifier of this reference (and the referencing anime
    /// information) that is unique within this service
    let uniqueIdentifier: String
    
    /// Name of the referencing anime
    let name: String
    
    /// The URL of the anime artwork
    let artwork: URL?
    
    /// Additional information of the reference that the parent
    /// service use to identify the reference
    let userInfo: [String: Any]
    
    /// The state of this anime on the tracking service
    var state: ListingAnimeTrackingState?
}

/// Representing a collection of anime references
struct ListingAnimeCollection {
    let parentService: ListingService
    
    /// The "user friendly" name of this collection
    let name: String
    
    /// Internal identifier of this collection unique to the parent service
    let identifier: String
    
    /// Additional information of the reference that the parent
    /// service use to identify the reference
    let userInfo: [String: Any]
    
    /// The list of anime references
    let collection: [ListingAnimeReference]
}

/// Representing a anime listing service
protocol ListingService: AnyObject {
    /// The name of the listing service
    var name: String { get }
    
    /// Report if this service is capable of generating `ListingAnimeInformation`
    var isCapableOfListingAnimeInformation: Bool { get }
    
    /// Report if this service is capable of receiving notifications about
    /// anime state changes notification (watched, watching, to-watch)
    var isCapableOfPersistingAnimeState: Bool { get }
    
    /// Report if NineAnimator can retrieve anime with states (watched, watching,
    /// to-watch) from this service
    var isCapableOfRetrievingAnimeState: Bool { get }
    
    init(_: NineAnimator)
    
    /// Find the corresponding reference to the anime link
    ///
    /// Should be implemented by all listing services
    func reference(from link: AnimeLink) -> NineAnimatorPromise<ListingAnimeReference>
    
    /// Update the state of an listed anime
    ///
    /// Only called if the service returns true for `isCapableOfPersistingAnimeState`
    func update(_ reference: ListingAnimeReference, newState: ListingAnimeTrackingState)
    
    /// Update the progress of an listed anime
    ///
    /// Only called if the service returns true for `isCapableOfPersistingAnimeState`
    func update(_ reference: ListingAnimeReference, didComplete episode: EpisodeLink)
    
    /// Retrieve the listing anime from the reference
    ///
    /// Only called if the service retruns true for `isCapableOfRetrievingAnimeState`
    func listingAnime(from reference: ListingAnimeReference) -> NineAnimatorPromise<ListingAnimeInformation>
    
    /// Retrieve anime collections of the current user
    ///
    /// Only called if the service returns true for `isCapableOfRetrievingAnimeState`
    func collections() -> NineAnimatorPromise<[ListingAnimeCollection]>
}

// MARK: - Implementations

extension ListingAnimeReference {
    enum Keys: CodingKey {
        case service
        case identifier
        case state
        case name
        case artwork
        case userInfo
    }
    
    init(_ parent: ListingService,
         name: String,
         identifier: String,
         state: ListingAnimeTrackingState?,
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
        
        // Decode user info
        let encodedUserInfo = try container.decode(Data.self, forKey: .userInfo)
        guard let decodedUserInfo = try PropertyListSerialization.propertyList(
                from: encodedUserInfo,
                options: [],
                format: nil
            ) as? [String: Any] else {
            throw NineAnimatorError.decodeError
        }
        userInfo = decodedUserInfo
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        
        // Encode basic info
        try container.encode(parentService.name, forKey: .service)
        try container.encode(uniqueIdentifier, forKey: .identifier)
        try container.encodeIfPresent(artwork, forKey: .artwork)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(state, forKey: .state)
        
        // Encode user info
        let encodedUserInfo = try PropertyListSerialization.data(
            fromPropertyList: userInfo,
            format: .binary,
            options: 0
        )
        try container.encode(encodedUserInfo, forKey: .userInfo)
    }
}

extension ListingAnimeCollection {
    init(_ parent: ListingService,
         name: String,
         identifier: String,
         collection: [ListingAnimeReference],
         userInfo: [String: Any] = [:]) {
        self.parentService = parent
        self.name = name
        self.identifier = identifier
        self.collection = collection
        self.userInfo = userInfo
    }
}
