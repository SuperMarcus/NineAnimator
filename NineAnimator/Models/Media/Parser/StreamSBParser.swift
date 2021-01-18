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
import Foundation

class StreamSBParser: VideoProviderParser {
    var aliases: [String] { [] }
    
    let videoSourceRegex = try! NSRegularExpression(
        pattern: #"file:"([^"]+)"#,
        options: .caseInsensitive
    )
    
    func parse(episode: Episode, with session: Session, forPurpose purpose: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        session.request(episode.target).responseString {
            response in
            do {
                let responseContent: String
                switch response.result {
                case let .success(c): responseContent = c
                case let .failure(error): throw error
                }
                
                let decodedString = try PackerDecoder().decode(responseContent)
                
                let videoURLString = try (self.videoSourceRegex
                    .firstMatch(in: decodedString)?
                    .firstMatchingGroup)
                    .tryUnwrap(.providerError("Could not get Video URL from Regex"))
                
                let videoURL = try URL(string: videoURLString).tryUnwrap()
                
                handler(BasicPlaybackMedia(
                    url: videoURL,
                    parent: episode,
                    contentType: "application/vnd.apple.mpegurl",
                    headers: ["Referer": episode.target.absoluteString],
                    isAggregated: true
                ), nil)
            } catch { handler(nil, error) }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
