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

class VeryStream: VideoProviderParser {
    var aliases: [String] {
        [ "VeryStream" ]
    }
    
    static let tokenRegex = try! NSRegularExpression(pattern: "<p style=\"\" class=\"\" id=\"videolink\">(.+)<\\/p>", options: .caseInsensitive)
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        session.request(episode.target).responseString {
            response in
            guard let text = response.value else {
                Log.error(response.error)
                return handler(nil, NineAnimatorError.responseError(
                    "response error: \(response.error?.localizedDescription ?? "Unknown")"
                ))
            }
            
            let tokenMatches = VeryStream.tokenRegex.matches(in: text, options: [], range: text.matchingRange)
            guard let tokenMatch = tokenMatches.first else { return handler(nil, NineAnimatorError.responseError(
                "Couldn't find token"
            )) }
            
            let token = text[tokenMatch.range(at: 1)]
            
            guard let sourceURL = URL(string: "/gettoken/\(token)", relativeTo: episode.target) else {
                return handler(nil, NineAnimatorError.responseError(
                   "source url not recongized"
               ))
            }
            
            Log.info("(VeryStream Parser) found %@", sourceURL)
            
            handler(BasicPlaybackMedia(
            url: sourceURL,
            parent: episode,
            contentType: "video/mp4",
            headers: [
                "User-Agent": self.defaultUserAgent
            ],
            isAggregated: false), nil)
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
