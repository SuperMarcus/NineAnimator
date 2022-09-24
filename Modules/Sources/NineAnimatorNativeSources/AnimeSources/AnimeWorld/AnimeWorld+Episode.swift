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
import SwiftSoup

extension NASourceAnimeWorld {
    static let knownServerMap = [
        "AnimeWorld": (name: "AnimeWorld", id: "9"),
        "VideoVard": (name: "VideoVard", id: "26"),
//        "Streamlare": (name: "Streamlare", id: "25")
        "Streamtape": (name: "Streamtape", id: "8"),
        "Doodstream": (name: "Doodstream", id: "2"),
//        "Userload": (name: "Userload", id: "17"),
        "SB": (name: "Streamsb", id: "19")
//        "VUP": (name: "VUP", id: "18")
    ]
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        self.requestManager.request(
            url: self.endpointURL.appendingPathComponent("api/episode/info"),
            handling: .ajax,
            parameters: [ "id": link.identifier ]
        )
        .responseDecodable(type: EpisodeResponse.self )
            .then {
                episodeInfo in Episode(
                    link,
                    target: try URL(protocolRelativeString: episodeInfo.grabber, relativeTo: self.endpointURL).tryUnwrap(),
                    parent: anime
                )
            }
        }
}

// MARK: - Data Structures
extension NASourceAnimeWorld {
    struct EpisodeResponse: Codable {
        let grabber: String
        let name: String
        let target: String
    }
}
