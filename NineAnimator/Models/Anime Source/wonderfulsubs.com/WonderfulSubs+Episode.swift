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

import AVKit
import Foundation

extension NASourceWonderfulSubs {
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        return request(
            ajaxPathDictionary: "/api/media/stream",
            query: [ "code": link.identifier ]
        ) .then {
            response in
            let supportedMimeTypes = AVURLAsset.audiovisualMIMETypes().map { $0.lowercased() }
            let availableAssets = try response
                .value(at: "urls", type: [NSDictionary].self)
                .compactMap {
                    asset -> (url: URL, type: String)? in
                    guard let url = URL(string: try asset.value(at: "src", type: String.self)) else {
                        return nil
                    }
                    let type = try asset.value(at: "type", type: String.self)
                    return (url, type)
                }
                .filter { supportedMimeTypes.contains($0.type.lowercased()) }
            let selectedAsset = try some(
                availableAssets.last,
                or: .responseError("NineAnimator does not support the playback of this episode")
            )
            
            // Construct the episode object
            return Episode(
                link,
                target: selectedAsset.url,
                parent: anime,
                referer: anime.link.link.absoluteString,
                userInfo: [ DummyParser.Options.contentType: selectedAsset.type ]
            )
        }
    }
}
