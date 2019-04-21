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
import SwiftSoup

extension NASourceNineAnime {
    func episode(from link: EpisodeLink, with anime: Anime, _ handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask? {
        let dataIdentifier = link.identifier.split(separator: "|").first!
        let ajaxHeaders: [String: String] = ["Referer": link.parent.link.absoluteString]
        let infoPath = "/ajax/episode/info?id=\(dataIdentifier)&server=\(link.server)"
        return request(ajax: infoPath, with: ajaxHeaders) {
            response, error in
            guard let responseJson = response else {
                return handler(nil, error)
            }
            
            guard let targetString = responseJson["target"] as? String,
                let target = URL(string: targetString)
                else {
                    Log.error("Target not defined or is invalid in response")
                    return handler(nil, NineAnimatorError.responseError(
                        "target url not defined or invalid"
                    ))
            }
            
            handler(Episode(link, target: target, parent: anime), nil)
        }
    }
}
