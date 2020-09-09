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
        var animeTitle: String
        var animeSession: String
        var snapshot: String
    }
    
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return self.requestManager.request(
            "/api",
            handling: .ajax,
            query: [ "m": "airing", "l": 32, "page": 1 ]
        ) .responseDecodable(
            type: AiringResponse.self,
            decoder: decoder
        ) .then {
            decodedResponse in try decodedResponse.data.map {
                animeItem in AnimeLink(
                    title: animeItem.animeTitle,
                    link: self.animeBaseUrl.appendingPathComponent(animeItem.animeSession),
                    image: try URL(string: animeItem.snapshot).tryUnwrap(.urlError),
                    source: self
                )
            }
        } .then { links in BasicFeaturedContainer(featured: [], latest: links) }
    }
}
