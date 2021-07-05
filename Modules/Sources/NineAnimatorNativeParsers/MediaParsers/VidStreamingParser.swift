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

import Alamofire
import AVKit
import Foundation
import NineAnimatorCommon

class VidStreamingParser: VideoProviderParser {
    var aliases: [String] {
        [ "VidStreaming", "VidCDN", "Gogo Server" ]
    }
    
    private static let videoSourceRegex = try! NSRegularExpression(
        pattern: "sources:\\[\\{file:\\s*'([^']+)",
        options: []
    )
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        session.request(episode.target).responseString {
            response in
            do {
                let responseContent = try response.value.tryUnwrap(.providerError("Resource is unreachable"))
                let resourceMatch = try VidStreamingParser
                    .videoSourceRegex
                    .firstMatch(in: responseContent)
                    .tryUnwrap(.providerError("The server sent an invalid or corrupted response"))
                let resourceUrlString = try resourceMatch.firstMatchingGroup.tryUnwrap(.unknownError)
                let resourceUrl = try URL(string: resourceUrlString).tryUnwrap(.urlError)
                let isHLSAsset = !resourceUrl.absoluteString.contains("mime=video/mp4")
                
                Log.info("(VidStreaming Parser) found asset at %@", resourceUrl.absoluteString)
                
                handler(BasicPlaybackMedia(
                    url: resourceUrl,
                    parent: episode,
                    contentType: isHLSAsset ? "application/vnd.apple.mpegurl" : "video/mp4",
                    headers: [ "Referer": episode.target.absoluteString ],
                    isAggregated: isHLSAsset
                ), nil)
            } catch { handler(nil, error) }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
