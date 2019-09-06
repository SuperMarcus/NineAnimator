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
    struct APIStreamResponse: Codable {
        var status: Int
        var urls: [APIStreamURLEntry]
    }
    
    struct APIStreamURLEntry: Codable {
        var src: String
        var type: String
        var label: String
        var captions: APIStreamCaptionsEntry?
    }
    
    struct APIStreamCaptionsEntry: Codable {
        var src: String
        var srcLang: String
        var label: String
    }
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        return request(
            ajaxPathDictionary: "/api/media/stream",
            query: [ "code": link.identifier ]
        ) .then {
            response in
            // A common error for WonderfulSubs
            if response["status"] as? Int == 404 {
                throw NineAnimatorError.responseError("This episode is not available on this server")
            }
            
            // Decode the asset url from the response
            let availableAssets = try DictionaryDecoder().decode(APIStreamResponse.self, from: response)
            let selectedAsset = try availableAssets
                .urls
                .last
                .tryUnwrap(.responseError("NineAnimator does not support the playback of this episode"))
            let targetUrl = try URL(string: selectedAsset.src).tryUnwrap()
            let mediaRetriever: PassthroughParser.MediaRetriever = {
                episode in
                // Assuming that all assets with external subtitles are aggregated, which may not be true
                if let captions = selectedAsset.captions {
                    return CompositionalPlaybackMedia(
                        url: targetUrl,
                        parent: episode,
                        contentType: selectedAsset.type,
                        headers: [:],
                        subtitles: [
                            (
                                url: try URL(string: captions.src).tryUnwrap(),
                                name: captions.label,
                                language: captions.srcLang
                            )
                        ]
                    )
                } else {
                    return BasicPlaybackMedia(
                        url: targetUrl,
                        parent: episode,
                        contentType: selectedAsset.type,
                        headers: [:],
                        isAggregated: DummyParser.registeredInstance!.isAggregatedAsset(mimeType: selectedAsset.type)
                    )
                }
            }
            
            // Construct the episode object
            return Episode(
                link,
                target: targetUrl,
                parent: anime,
                referer: anime.link.link.absoluteString,
                userInfo: [ PassthroughParser.Options.playbackMediaRetriever: mediaRetriever ]
            )
        }
    }
}
