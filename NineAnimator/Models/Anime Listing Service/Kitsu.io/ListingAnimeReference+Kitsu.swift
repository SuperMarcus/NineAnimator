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
    init(_ parent: Kitsu, withAnimeObject animeObject: Kitsu.APIObject) throws {
        // Save identifier
        let uniqueIdentifier = animeObject.identifier
        let name = (animeObject.attributes["canonicalTitle"] as? String) ?? "Untitled"
        var artwork: URL?
        
        // Parse the artwork url - using original poster image by default
        if let artworkAttribute = animeObject.attributes["posterImage"] as? NSDictionary,
            let originalArtworkUrl = artworkAttribute["original"] as? String {
            artwork = URL(string: originalArtworkUrl)
        }
        
        // Call the parent init method
        self.init(parent, name: name, identifier: uniqueIdentifier, state: nil, artwork: artwork, userInfo: [:])
    }
}
