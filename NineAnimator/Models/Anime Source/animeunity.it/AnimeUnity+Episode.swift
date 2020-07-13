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
import SwiftSoup

extension NASourceAnimeUnity {
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise.firstly {
            try URL(string: link.identifier).tryUnwrap()
        } .thenPromise {
            episodePageUrl in self
                .requestManager
                .request(url: episodePageUrl, handling: .browsing)
                .responseVoid
        } .then {
            _ in
            let videoUrl = try URL(string: link.identifier + ".mp4").tryUnwrap()
            return Episode(
                link,
                target: videoUrl,
                parent: anime
            )
        }
    }
}
