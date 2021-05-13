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

extension NASourceWonderfulSubs {
    /// Construct NineAnimator AnimeLink with the series entry found
    /// in WonderfulSubs' response objects
    func constructAnimeLink(from seriesEntry: NSDictionary, useWidePoster: Bool = false, withParent parent: AnimeLink? = nil) throws -> AnimeLink {
        // Parse basic information
        let title = try seriesEntry.value(at: "title", type: String.self)
        let path = try (parent?.link.path ?? seriesEntry.value(at: "url", type: String.self))
        let link = endpointURL.appendingPathComponent(path)
        
        // Artwork URL
        let artworkUrl: URL
        
        do {
            // Parse artwork resource list
            let artworkResourceList: [NSDictionary]
            if useWidePoster {
                artworkResourceList = try seriesEntry.value(at: "poster_wide", type: [NSDictionary].self)
            } else { artworkResourceList = try seriesEntry.value(at: "poster_tall", type: [NSDictionary].self) }
            
            // Select the artwork with the highest resolution
            guard let artworkResource = artworkResourceList.last else {
                throw NineAnimatorError.responseError("No artwork found")
            }
            
            // Retrieve the source URL of the artwork
            artworkUrl = try some(
                URL(string: artworkResource.value(at: "source", type: String.self)),
                or: .urlError
            )
        } catch {
            // Reported by [Awsomedude](https://github.com/Awsomedude)
            // Seems some anime don't have "poster_tall, poster_wide" and sometimes they do but have null
            Log.info("[NASourceWonderfulSubs] Poster not found for an anime entry. Using placeholder value instead.")
            artworkUrl = NineAnimator.placeholderArtworkUrl
        }
        
        // Construct the anime link
        return AnimeLink(title: title, link: link, image: artworkUrl, source: self)
    }
}
