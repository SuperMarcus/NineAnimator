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

extension NASourceHAnime {
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        guard let sources = anime.additionalAttributes["hanime.sources"] as? [String: String] else {
            return .fail(NineAnimatorError.providerError("Streaming source cannot be found"))
        }
        
        return NineAnimatorPromise.firstly {
            let selectedItem = try (
                sources["720"] ??
                sources["480"] ??
                sources["360"]
            ).tryUnwrap(.decodeError)
            
            let targetUrl = try URL(string: selectedItem).tryUnwrap(.urlError)
            
            return Episode(
                link,
                target: targetUrl,
                parent: anime,
                userInfo: [
                    DummyParser.Options.headers: [
                        "User-Agent": self.sessionUserAgent,
                        "Referer": "https://player3.hanime.tv"
                    ],
                    DummyParser.Options.isAggregated: true,
                    DummyParser.Options.contentType: "application/vnd.apple.mpegurl"
                ]
            )
        }
    }
}
