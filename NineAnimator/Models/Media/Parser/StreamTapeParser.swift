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

class StreamTapeParser: VideoProviderParser {
    var aliases: [String] { [ "streamtape", "Sreamtape" ] }
    
    static let playerSourceRegex = try! NSRegularExpression(
        pattern: "'innerHTML'\\]\\s*=\\s*'([^']+)",
        options: []
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
                
                let sourceUrlString = try StreamTapeParser
                    .playerSourceRegex
                    .firstMatch(in: responseContent)
                    .tryUnwrap(.providerError("Unable to find the streaming resource"))
                    .firstMatchingGroup
                    .tryUnwrap()
                let sourceUrl = try URL(
                    protocolRelativeString: sourceUrlString,
                    relativeTo: episode.target
                ) .tryUnwrap()
                
                Log.info("(StreamTape Parser) found asset at %@", sourceUrl)
                
                let media = BasicPlaybackMedia(
                    url: sourceUrl,
                    parent: episode,
                    contentType: "video/mp4",
                    headers: [:],
                    isAggregated: false
                )
                
                handler(media, nil)
            } catch { handler(nil, error) }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
