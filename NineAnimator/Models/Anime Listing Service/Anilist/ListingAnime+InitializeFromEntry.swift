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
}

extension ListingAnimeCollection {
    init(_ parent: Anilist, withCollectionEntry collectionEntry: NSDictionary) throws {
        guard let name = collectionEntry["name"] as? String,
            let entries = collectionEntry["entries"] as? [NSDictionary] else {
            throw NineAnimatorError.decodeError
        }
        self.init(
            parent,
            name: name,
            identifier: name,
            collection: try entries.map {
                entry in
                guard let mediaEntry = entry["media"] as? NSDictionary else {
                    throw NineAnimatorError.decodeError
                }
                return try ListingAnimeReference(parent, withMediaEntry: mediaEntry)
            },
            userInfo: collectionEntry as! [String: Any]
        )
    }
}
