//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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

import Foundation
import Alamofire
import AVKit

class MyCloudParser: VideoProviderParser {
    static let videoIdentifierRegex = try! NSRegularExpression(pattern: "videoId:\\s*'([^']+)", options: .caseInsensitive)
    static let videoSourceRegex = try! NSRegularExpression(pattern: "\"file\":\"([^\"]+)", options: .caseInsensitive)
    
    func parse(url: URL, with session: SessionManager, onCompletion handler: @escaping NineAnimatorCallback<AVPlayerItem>) -> NineAnimatorAsyncTask {
        let additionalHeaders: HTTPHeaders = [
            "Referer": "https://www1.9anime.to/watch",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "User-Agnet": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.1 Safari/605.1.15",
            "Host": "mcloud.to"
        ]
        
        let playerAdditionalHeaders: HTTPHeaders = [
            "Referer": url.absoluteString,
            "User-Agnet": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.1 Safari/605.1.15"
        ]
        return session.request(url, headers: additionalHeaders).responseString {
            response in
            guard let text = response.value else {
                debugPrint("Error: \(response.error?.localizedDescription ?? "Unknown")")
                handler(nil, NineAnimatorError.responseError("response error: \(response.error?.localizedDescription ?? "Unknown")"))
                return
            }
            
            let matches = MyCloudParser.videoSourceRegex.matches(in: text, options: [], range: text.matchingRange)
            
            guard let match = matches.first else {
                handler(nil, NineAnimatorError.responseError("no matches for source url"))
                return
            }
            
            guard let sourceUrl = URL(string: text[match.range(at: 1)]) else {
                handler(nil, NineAnimatorError.responseError("source url not recongized"))
                return
            }
            
            debugPrint("Info: (MyCloud Parser) found asset at \(sourceUrl.absoluteString)")
            
            let item = AVPlayerItem(url: sourceUrl, headers: playerAdditionalHeaders)
            
            handler(item, nil)
        }
    }
}
