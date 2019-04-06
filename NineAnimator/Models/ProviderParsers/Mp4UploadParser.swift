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

class Mp4UploadParser: VideoProviderParser {
    static let playerOptionRegex = try! NSRegularExpression(pattern: "'([^']+)'\\.split", options: .caseInsensitive)
    
    func parse(episode: Episode, with session: SessionManager, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        return session.request(episode.target).responseString {
            response in
            guard let text = response.value else {
                Log.error(response.error)
                return handler(nil, NineAnimatorError.responseError(
                    "response error: \(response.error?.localizedDescription ?? "Unknown")"
                ))
            }
            
            let matches = Mp4UploadParser.playerOptionRegex.matches(in: text, options: [], range: text.matchingRange)
            guard let match = matches.first else { return handler(nil, NineAnimatorError.responseError(
                "no matches found for player"
            )) }
            
            let playerOptionsString = text[match.range(at: 1)]
            let playerOptions = playerOptionsString.split(separator: "|")
            
            let serverPrefix = playerOptions[49]
            let serverPort = playerOptions[91]
            let mediaIdentifier = playerOptions[90]
            
            guard let sourceURL = URL(string: "https://\(serverPrefix).mp4upload.com:\(serverPort)/d/\(mediaIdentifier)/video.mp4") else {
                return handler(nil, NineAnimatorError.responseError(
                    "source url not recongized"
                ))
            }
            
            Log.info("(Mp4Upload Parser) found asset at %@", sourceURL.absoluteString)
            
            handler(BasicPlaybackMedia(
                url: sourceURL,
                parent: episode,
                contentType: "video/mp4",
                headers: [
                    "User-Agent": self.defaultUserAgent,
                    "Origin": episode.target.absoluteString
                ],
                isAggregated: false), nil)
        }
    }
}
