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
import AVKit
import Foundation

class HydraXParser: VideoProviderParser {
    var aliases: [String] {
        return [ "HydraX", "replay.watch" ]
    }
    
    private static let resourceRequestUrl = URL(string: "https://multi.idocdn.com/vip")!
    
    private static let resourceInfoRegex = try! NSRegularExpression(
        pattern: "options\\s+=\\s+(\\{[^}]+\\})",
        options: []
    )
    
    private struct ResourceOptions: Codable {
        var key: String
        var type: String
        var value: String
//        var aspectratio: String
    }
    
    private struct ResourceResponse: Codable {
        var status: Bool
        var hash: String
        var link: String
        var thumbnail: String
    }
    
    func parse(episode: Episode, with session: SessionManager, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        return NineAnimatorPromise<String> {
            callback in session.request(episode.target).responseString {
                callback($0.value, $0.error)
            }
        } .thenPromise {
            responseContent -> NineAnimatorPromise<Data> in
            let hydraxSlug = try formDecode(
                try episode.target.fragment.tryUnwrap(.responseError("HydraX resource must contain a fragment"))
            ) .value(at: "slug", type: String.self)
            let resourceOptionsData = try HydraXParser
                .resourceInfoRegex
                .firstMatch(in: responseContent)
                .tryUnwrap(.responseError("Unable to find information identifying the playback resource"))
                .firstMatchingGroup!
                .replacingOccurrences(of: "([a-zA-Z0-9_-]+):([^,\\n\\r]+,*)", with: "\"$1\":$2", options: [.regularExpression])
                .replacingOccurrences(of: "HYDRAX_SLUG", with: "\"\(hydraxSlug)\"")
                .data(using: .utf8)
                .tryUnwrap()
            let resourceOptions = try JSONDecoder().decode(
                ResourceOptions.self,
                from: resourceOptionsData
            )
            
            return NineAnimatorPromise {
                callback in session.request(
                    HydraXParser.resourceRequestUrl,
                    method: .post,
                    parameters: [
                        "key": resourceOptions.key,
                        "type": resourceOptions.type,
                        "value": resourceOptions.value,
                        "dataType": "m3u8"
                    ],
                    encoding: URLEncoding.default,
                    headers: nil
                ) .responseData { callback($0.value, $0.error) }
            }
        } .then {
            resourceResponseData in
            let resource = try JSONDecoder().decode(
                ResourceResponse.self,
                from: resourceResponseData
            )
            let target = try URL(string: resource.link).tryUnwrap()
            return BasicPlaybackMedia(
                url: target,
                parent: episode,
                contentType: "application/vnd.apple.mpegurl",
                headers: [:],
                isAggregated: true
            )
        } .handle(handler)
    }
}
