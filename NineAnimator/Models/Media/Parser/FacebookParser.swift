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

class FacebookParser: VideoProviderParser {
    var aliases: [String] { [ "fdserver" ] }
    
    static let videoSourceRegex = try! NSRegularExpression(
        pattern: "\"file\":\"([^\"]+)",
        options: .caseInsensitive
    )
    
    func parse(episode: Episode, with session: Session, forPurpose purpose: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        if episode.target.host?.lowercased() == "embed.vodstream.xyz" {
            return parseWithVodstream(episode: episode, with: session, onCompletion: handler)
        } else {
            // Currently only supports parsing from vodstream domain
            return NineAnimatorPromise.fail(NineAnimatorError.providerError(
                "No parser compatible with Episode's target domain"
            )).handle(handler)
        }
    }
    
    func parseWithVodstream(episode: Episode, with session: Session, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        session.request(
            episode.target,
            headers: [ "Referer": episode.parent.link.link.absoluteString ]
        ).responseString {
            response in
            do {
                let responseContent: String
                switch response.result {
                case let .success(c): responseContent = c
                case let .failure(error): throw error
                }
                
                // Find Source URL
                let sourceURLString = try FacebookParser.videoSourceRegex.firstMatch(in: responseContent)
                    .tryUnwrap()
                    .firstMatchingGroup
                    .tryUnwrap()
                    .replacingOccurrences(of: #"\/"#, with: "/") // Remove "/" escape characters
                
                let sourceURL = try URL(string: sourceURLString).tryUnwrap()
                
                Log.info("(FacebookParser) found asset at %@", sourceURL)
                
                handler(BasicPlaybackMedia(
                    url: sourceURL,
                    parent: episode,
                    contentType: "video/mp4",
                    headers: [
                        "referer": "https://embed.streamx.me/",
                        "User-Agent": self.defaultUserAgent
                    ],
                    isAggregated: false
                ), nil)
            } catch { handler(nil, error) }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true // Seems to be reliable
    }
}
