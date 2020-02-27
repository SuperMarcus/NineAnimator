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

class KiwikParser: VideoProviderParser {
    var aliases: [String] {
        [ "Kiwik", "kwik" ]
    }
    
    static let playerSourceRegex = try! NSRegularExpression(
        pattern: "'src\\\\':\\\\'([^\\\\']+)",
        options: []
    )
    
    static let playerSourceRegex2 = try! NSRegularExpression(
        pattern: "source=\\\\'([^\\\\]+)",
        options: []
    )
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let additionalResourceRequestHeaders: HTTPHeaders = [
            "Referer": episode.parent.link.link.absoluteString
        ]
        return session.request(
            episode.target,
            headers: additionalResourceRequestHeaders
        ).responseString {
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
                let sourceUrl = try (
                    KiwikParser.playerSourceRegex.firstMatch(in: decodedPackerScript)?.firstMatchingGroup
                    ?? KiwikParser.playerSourceRegex2.firstMatch(in: decodedPackerScript)?.firstMatchingGroup
                ).tryUnwrap(
                    .providerError("Cannot find a streambale resource in the selected page")
                )
                
                let sourceURL = try URL(string: sourceUrl).tryUnwrap(.urlError)
                
                let aggregated = sourceURL.pathExtension.lowercased().components(separatedBy: "?")[0] == "m3u8"
                
                Log.info("(Kiwik Parser) found asset at %@ (HLS: %@)", sourceURL.absoluteString, aggregated)
                
                handler(BasicPlaybackMedia(
                    url: sourceURL,
                    parent: episode,
                    contentType: aggregated ? "application/vnd.apple.mpegurl" : "video/mp4",
                    headers: [ "Referer": episode.target.absoluteString ],
                    isAggregated: aggregated
                ), nil)
            } catch { handler(nil, error) }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        if #available(iOS 13.0, *) {
            // Kwik also only provides an event playlist
            return purpose != .download
        }
        
        return true
    }
}
