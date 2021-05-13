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

class Mp4UploadParser: VideoProviderParser {
    var aliases: [String] {
        [ "Mp4Upload", "Mp4 Upload" ]
    }
    
    static let playerSourceRegex = try! NSRegularExpression(
        pattern: "player\\.src\\(\"([^\"]+)",
        options: []
    )
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        session.request(episode.target).responseString {
            response in
            do {
                let responseContent: String
                switch response.result {
                case let .success(c): responseContent = c
                case let .failure(error): throw error
                }
                
                // Feed the entire webpage to the packer decoder
                let decodedPackerScript = try PackerDecoder().decode(responseContent)
                
                // Find the source URL
                let sourceUrl = try (Mp4UploadParser
                    .playerSourceRegex
                    .firstMatch(in: decodedPackerScript)?
                    .firstMatchingGroup).tryUnwrap(.providerError("Unable to find the streaming resource"))
                let sourceURL = try URL(string: sourceUrl).tryUnwrap(.urlError)
                
                Log.info("(Mp4Upload Parser) found asset at %@", sourceURL.absoluteString)
                
                handler(BasicPlaybackMedia(
                    url: sourceURL,
                    parent: episode,
                    contentType: "video/mp4",
                    headers: [
                        "User-Agent": self.defaultUserAgent,
                        "Referer": episode.target.absoluteString
                    ],
                    isAggregated: false), nil)
            } catch { handler(nil, error) }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        purpose != .googleCast
    }
}
