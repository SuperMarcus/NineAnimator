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

import Alamofire
import Foundation

/// Parser for animedao's ProxyData server
class ProxyDataParser: VideoProviderParser {
    var aliases: [String] { [] }
    
    func parse(episode: Episode,
               with session: SessionManager,
               forPurpose _: Purpose,
               onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise.firstly {
            episode.source as? BaseSource
        } .thenPromise {
            source in NineAnimatorPromise<URL> {
                callback in source.browseSession.request(episode.target).responseString {
                    response in
                    if let finalUrl = response.response?.url {
                        callback(finalUrl, nil)
                    } else { callback(nil, response.error ?? NineAnimatorError.unknownError) }
                }
            }
        } .then {
            finalUrl in
            let components = try URLComponents(
                url: finalUrl,
                resolvingAgainstBaseURL: true
            ).tryUnwrap()
            let resourceIdentifier = try components
                .queryItems
                .tryUnwrap(.responseError("Resource parameters are missing"))
                .first { $0.name == "id" }
                .tryUnwrap(.responseError("Resource identifier not found"))
                .value
                .tryUnwrap(.responseError("Resource identifier does not have a value"))
            let resourceUrl = try URL(
                string: "https://proxydata.me/hls/\(resourceIdentifier)/\(resourceIdentifier).playlist.m3u8"
            ).tryUnwrap()
            
            return BasicPlaybackMedia(
                url: resourceUrl,
                parent: episode,
                contentType: "application/x-mpegURL",
                headers: [:],
                isAggregated: true
            )
        } .handle(handler)
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        // Seems only suitable for playback, needs further investigation
        return purpose == .playback
    }
}
