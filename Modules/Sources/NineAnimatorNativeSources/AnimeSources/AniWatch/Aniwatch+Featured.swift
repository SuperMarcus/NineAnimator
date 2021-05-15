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

import Alamofire
import Foundation
import NineAnimatorCommon
import SwiftSoup

extension NASourceAniwatch {
    /*fileprivate struct SeasonalAnimeResponse: Decodable {
        let success: Bool
        let error: String?
        let entries: [AniwatchAnimeEntry]?
    }
    
    fileprivate struct AniwatchAnimeEntry: Decodable {
        let title: String
        let cover: String
        let detail_id: Int
    }*/
    
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        .fail()
        /*self.requestManager.request(
            url: self.ajexEndpoint.absoluteString,
            handling: .default,
            method: .post,
            parameters: [
                "controller": "Anime",
                "action": "getSeasonalAnime",
                "current_index": "null",
                "current_year": "null"
            ],
            encoding: JSONEncoding(),
            headers: [ "x-path": "/seasonal" ]
        ).responseDecodable(type: SeasonalAnimeResponse.self).then {
            response -> FeaturedContainer in
            guard response.success == true else {
                throw NineAnimatorError.decodeError(try response.error.tryUnwrap())
            }
            let seasonalAnime = try response.entries
                .tryUnwrap(.decodeError("Anime Entries"))
                .map {
                animeEntry -> AnimeLink in
                
                let animeURL = try URL(string: self.endpoint + "/anime/\(animeEntry.detail_id)").tryUnwrap(.urlError)
                
                let animeImage = try URL(string: animeEntry.cover).tryUnwrap(.urlError)
                
                return AnimeLink(
                    title: animeEntry.title,
                    link: animeURL,
                    image: animeImage,
                    source: self
                )
            }
            
            return BasicFeaturedContainer(
                featured: seasonalAnime,
                latest: []
            )
        }*/
    }
}
