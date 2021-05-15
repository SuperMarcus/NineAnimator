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
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        .fail(.contentUnavailableError("WonderfulSubs is no longer available on NineAnimator"))
//        NineAnimatorPromise<[AnimeLink]>
//            .queue(listOfPromises: [ retrieveFeaturedAnimePromise, retrieveLatestAnimePromise ])
//            .then { results in BasicFeaturedContainer(featured: results[0], latest: results[1]) }
    }
//
//    private var retrieveFeaturedAnimePromise: NineAnimatorPromise<[AnimeLink]> {
//        request(
//            ajaxPathDictionary: "/api/media/popular?count=12",
//            headers: [ "Referer": endpoint ]
//        ) .then {
//            response in
//            let series = try response.value(at: "json.series", type: [NSDictionary].self)
//            return try series.map { try self.constructAnimeLink(from: $0, useWidePoster: true) }
//        }
//    }
//
//    private var retrieveLatestAnimePromise: NineAnimatorPromise<[AnimeLink]> {
//        request(
//            ajaxPathDictionary: "/api/media/latest?count=12",
//            headers: [ "Referer": endpoint ]
//        ) .then {
//            response in
//            let series = try response.value(at: "json.series", type: [NSDictionary].self)
//            return try series.map { try self.constructAnimeLink(from: $0) }
//        }
//    }
}
