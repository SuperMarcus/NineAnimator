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
import SwiftSoup

class RapidVideoParser: VideoProviderParser {
    var aliases: [String] {
        return [ "RapidVideo", "Rapid Video" ]
    }
    
    func parse(episode: Episode, with session: SessionManager, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let additionalHeaders: HTTPHeaders = [
            "Referer": episode.target.absoluteString
        ]
        return session.request(episode.target, headers: additionalHeaders).responseString {
            response in
            guard let value = response.value else {
                Log.error(response.error)
                return handler(nil, NineAnimatorError.responseError(
                    "response error: \(response.error?.localizedDescription ?? "Unknown")"
                ))
            }
            do {
                let bowl = try SwiftSoup.parse(value)
                let sourceString = try bowl.select("video>source").attr("src")
                guard let sourceURL = URL(string: sourceString) else {
                    return handler(nil, NineAnimatorError.responseError(
                        "unable to convert video source to URL"
                    ))
                }
                
                Log.info("(RapidVideo Parser) found asset at %@", sourceURL.absoluteString)
                
                handler(BasicPlaybackMedia(
                    url: sourceURL,
                    parent: episode,
                    contentType: "video/mp4",
                    headers: additionalHeaders,
                    isAggregated: false), nil)
            } catch { handler(nil, error) }
        }
    }
}
