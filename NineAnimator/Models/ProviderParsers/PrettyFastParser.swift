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

class PrettyFastParser: VideoProviderParser {
    static let videoSourceRegex = try! NSRegularExpression(pattern: "file:\\s+'([^\']+)", options: .caseInsensitive)
    
    func parse(episode: Episode, with session: SessionManager, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let userAgent = (episode.source as? BaseSource)?.sessionUserAgent ?? defaultUserAgent
        let episodeLinkPath = episode.link.identifier.split(separator: "|").last!
        
        guard let refererUrl = URL(string: String(episodeLinkPath), relativeTo: episode.parentLink.link) else {
            return NineAnimatorPromise.fail(.urlError).handle(handler)
        }
        
        let additionalHeaders: HTTPHeaders = [
            "Referer": refererUrl.absoluteString,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3",
            "User-Agnet": userAgent,
            "accept-language": "en-us"
        ]
        
        let playerAdditionalHeaders: HTTPHeaders = [
            "Referer": episode.target.absoluteString,
            "User-Agnet": userAgent
        ]
        
        return session.request(episode.target, headers: additionalHeaders).responseString {
            response in
            guard let text = response.value else {
                Log.error(response.error)
                return handler(nil, NineAnimatorError.responseError(
                    "response error: \(response.error?.localizedDescription ?? "Unknown")"
                ))
            }
            
            let matches = PrettyFastParser.videoSourceRegex.matches(
                in: text, range: text.matchingRange
            )
            
            guard let match = matches.first else {
                return handler(nil, NineAnimatorError.responseError(
                    "no matches for source url"
                ))
            }
            
            guard let sourceURL = URL(string: text[match.range(at: 1)]) else {
                return handler(nil, NineAnimatorError.responseError(
                    "source url not recongized"
                ))
            }
            
            Log.info("(PrettyFast Parser) found asset at %@", sourceURL.absoluteString)
            
            //MyCloud might not support Chromecast, since it uses COR checking
            handler(BasicPlaybackMedia(
                url: sourceURL,
                parent: episode,
                contentType: "application/x-mpegURL",
                headers: playerAdditionalHeaders,
                isAggregated: true), nil)
        }
    }
}
