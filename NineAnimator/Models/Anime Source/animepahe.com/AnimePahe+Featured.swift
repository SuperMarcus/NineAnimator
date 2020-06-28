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

extension NASourceAnimePahe {
    fileprivate struct AiringResponse: Codable {
        var data: [AiringAnimeItem]
    }
    
    fileprivate struct AiringAnimeItem: Codable {
        var anime_title: String
        var anime_slug: String
        var snapshot: String
    }
    
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        self.requestManager.request(
            "/api",
            handling: .ajax,
            query: [ "m": "airing", "l": 32, "page": 1 ]
        ) .responseDictionary
          .then {
            response in try DictionaryDecoder().decode(AiringResponse.self, from: response)
        } .then {
            decodedResponse in try decodedResponse.data.map {
                animeItem in AnimeLink(
                    title: animeItem.anime_title,
                    link: self.animeBaseUrl.appendingPathComponent(animeItem.anime_slug),
                    image: try URL(string: animeItem.snapshot).tryUnwrap(.urlError),
                    source: self
                )
            }
        } .then { links in BasicFeaturedContainer(featured: [], latest: links) }
    }
}
