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

extension NASourceNineAnime {
    func episode(from link: EpisodeLink, with anime: Anime, _ handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask? {
        let linkComponents = link.identifier.split(separator: "|")
        let dataIdentifier = linkComponents.first ?? ""
        let episodePath = linkComponents.last ?? ""
        
        let refererUrl = URL(
            string: String(episodePath),
            relativeTo: link.parent.link
        ) ?? link.parent.link
        let infoPath = "/ajax/episode/info"
        
        return MyCloudParser.retrieveWindowKey(
            with: browseSession,
            referer: link.parent.link.appendingPathComponent(String(episodePath))
        ) .then {
            [
                "id": dataIdentifier,
                "server": link.server,
                "mcloud": $0
            ]
        } .thenPromise {
            requestParameters in NineAnimatorPromise {
                self.signedRequest(
                    ajax: infoPath,
                    parameters: requestParameters,
                    with: [ "Referer": refererUrl.absoluteString ],
                    completion: $0
                )
            }
        } .then {
            responseJson -> Episode in
            
            guard let targetString = responseJson["target"] as? String,
                let target = URL(string: targetString) else {
                Log.error("Target not defined or is invalid in response")
                throw NineAnimatorError.responseError(
                    "target url not defined or invalid"
                )
            }
            
            return Episode(link, target: target, parent: anime)
        } .handle(handler)
    }
}
