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

/// Representing the tracking state of the listed anime
public enum ListingAnimeTrackingState: String, Codable {
    case toWatch
    case watching
    case finished
}

/// The current tracking state of the user if the state is watching
public struct ListingAnimeTracking {
    /// The user's current progress
    public var currentProgress: Int
    
    /// Total number of episodes available
    public var episodes: Int?
    
    /// Obtain the next tracking state with the updated progress
    public func newTracking(withUpdatedProgress progress: Int) -> ListingAnimeTracking {
        ListingAnimeTracking(currentProgress: progress, episodes: episodes)
    }
    
    /// Public initializer
    public init(currentProgress: Int, episodes: Int? = nil) {
        self.currentProgress = currentProgress
        self.episodes = episodes
    }
}

/// Representing a reference that can be used to identify a particular anime on the `Listing Service`
///
/// Hash is calculated based on the `ListingService` and the `uniqueIdentifier`
public struct ListingAnimeReference: Codable, Hashable {
    public unowned let parentService: ListingService
    
    /// An identifier of this reference (and the referencing anime
    /// information) that is unique within this service
    public let uniqueIdentifier: String
    
    /// Name of the referencing anime
    public let name: String
    
    /// The URL of the anime artwork
    public let artwork: URL?
    
    /// Additional information of the reference that the parent
    /// service use to identify the reference
    public let userInfo: [String: Any]
    
    /// The state of this anime on the tracking service
    public var state: ListingAnimeTrackingState?
}

/// Representing a collection of anime references
public protocol ListingAnimeCollection: ContentProvider {
    var parentService: ListingService { get }
}

/// Representing a anime listing service
public protocol ListingService: AnyObject {
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
    
    /// Default initializer
    init(_: NineAnimator)
    
    /// Find the corresponding reference to the anime link
    ///
    /// Should be implemented by all listing services
    func reference(from link: AnimeLink) -> NineAnimatorPromise<ListingAnimeReference>
    
    /// Obtain the tracking information for the current user associated with the `ListingAnimeReference`
    ///
    /// `ListingService`s should obtain and cache the `ListingAnimeTracking` objects when fetching and
    /// updating user collections.
    func progressTracking(for reference: ListingAnimeReference) -> ListingAnimeTracking?
    
    /// Update the state of an listed anime
    ///
    /// Only called if the service returns true for `isCapableOfPersistingAnimeState`
    func update(_ reference: ListingAnimeReference, newState: ListingAnimeTrackingState)
    
    /// The new tracking state that the user intends to update on the tracking website.
    func update(_ reference: ListingAnimeReference, newTracking: ListingAnimeTracking)
    
    /// Update the progress of an listed anime
    ///
    /// The episodeNumber passed in as parameter is not guarenteed to be the furtherest episode
    /// that the user has completed. It is the episode that the user has just finished watching.
    ///
    /// Only called if the service returns true for `isCapableOfPersistingAnimeState`
    /// - Parameter shouldUpdateTrackingState: True by Default. Moves the ListingAnimeReference to the user's Completed list if they have finished watching the last episode.
    func update(_ reference: ListingAnimeReference, didComplete episode: EpisodeLink, episodeNumber: Int?, shouldUpdateTrackingState: Bool)
    
    /// Retrieve the listing anime from the reference
    ///
    /// Only called if the service retruns true for `isCapableOfRetrievingAnimeState`
    func listingAnime(from reference: ListingAnimeReference) -> NineAnimatorPromise<ListingAnimeInformation>
    
    /// Retrieve anime collections of the current user
    ///
    /// Only called if the service returns true for `isCapableOfRetrievingAnimeState`
    func collections() -> NineAnimatorPromise<[ListingAnimeCollection]>
    
    /// Called when the service is registered
    func onRegister()
    
    /// Called when the service should logout the current user.
    ///
    /// Only called if the service returns true for `isCapableOfRetrievingAnimeState`
    func deauthenticate()
}
