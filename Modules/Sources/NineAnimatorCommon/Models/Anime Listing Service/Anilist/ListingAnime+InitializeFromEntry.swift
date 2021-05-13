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

extension ListingAnimeReference {
    init(_ parent: Anilist, withMediaEntry mediaEntry: NSDictionary) throws {
        // Required Information
        guard let identifier = mediaEntry["id"] as? Int,
            let artworkString = mediaEntry.value(forKeyPath: "coverImage.extraLarge") as? String,
            let artwork = URL(string: artworkString),
            let title = mediaEntry.value(forKeyPath: "title.userPreferred") as? String else {
            throw NineAnimatorError.decodeError
        }
        
        var state: ListingAnimeTrackingState?
        if let mediaListState = mediaEntry.value(forKeyPath: "mediaListEntry.status") as? String {
            // enum MediaListStatus, treating DROPPED as nil
            switch mediaListState {
            case "CURRENT": state = .watching
            case "PLANNING": state = .toWatch
            case "COMPLETED", "REPEATING": state = .finished
            default: break
            }
        }
        
        self.init(parent, name: title, identifier: String(identifier), state: state, artwork: artwork, userInfo: [:])
    }
    
    init(_ parent: Anilist, withMediaObject mediaObject: Anilist.GQLMedia) throws {
        let libraryStatus: ListingAnimeTrackingState?
        
        if let referenceState = mediaObject.mediaListEntry?.status {
            switch referenceState {
            case .current: libraryStatus = .watching
            case .planning: libraryStatus = .toWatch
            case .completed, .repeating: libraryStatus = .finished
            default: libraryStatus = nil
            }
        } else { libraryStatus = nil }
        
        self.init(
            parent,
            name: try (mediaObject.title?.userPreferred).tryUnwrap(.decodeError),
            identifier: String(try mediaObject.id.tryUnwrap(.decodeError)),
            state: libraryStatus,
            artwork: try URL(
                string: try (mediaObject.coverImage?.extraLarge ?? mediaObject.coverImage?.large).tryUnwrap(.decodeError)
            ).tryUnwrap(.decodeError),
            userInfo: [:]
        )
    }
}

extension StaticListingAnimeCollection {
    init(_ parent: Anilist, withCollectionObject collection: Anilist.GQLMediaListGroup) throws {
        self.init(
            parent,
            name: try collection.name.tryUnwrap(),
            identifier: try collection.name.tryUnwrap(),
            collection: try collection.entries.tryUnwrap().map {
                listItem in
                let media = try listItem.media.tryUnwrap()
                let reference = try ListingAnimeReference(parent, withMediaObject: media)
                
                // Obtain the tracking state and contribute it to the parent
                if let tracking = parent.createReferenceTracking(from: listItem.mediaList, withSupplementalMedia: media) {
                    parent.contributeReferenceTracking(tracking, forReference: reference)
                }
                
                return reference
            } .sorted { $0.name < $1.name }
        )
    }
}
