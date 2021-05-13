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

/// A passthrough parser that passes the target url of the anime as the playback media
public class DummyParser: VideoProviderParser {
    public var aliases: [String] { [] }
    
    public func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let dummyTask = AsyncTaskContainer()
        
        DispatchQueue.main.async {
            let options = episode.userInfo
            var isAggregatedAsset = false
            
            // Infer isAggregated from mime type
            if let contentType = options[Options.contentType] as? String {
                isAggregatedAsset = DummyParser.isAggregatedAsset(mimeType: contentType)
            }
            
            // Attach Referer header to all requests for backwards compatibility
            var headers = [ "Referer": episode.link.parent.link.absoluteString ]
            
            if let additionalHeaders = options[Options.headers] as? [String: String] {
                // Combine headers with the additionalHeaders taking prioity
                headers.merge(additionalHeaders) { _, new in new }
            }
            
            handler(BasicPlaybackMedia(
                url: episode.target,
                parent: episode,
                contentType: (options[Options.contentType] as? String) ?? "video/mp4",
                headers: headers,
                isAggregated: (options[Options.isAggregated] as? Bool) ?? isAggregatedAsset
            ), nil)
        }
        
        return dummyTask
    }
    
    public enum Options {
        public static let contentType: String =
            "com.marcuszhou.nineanimator.providerparser.DummyParser.option.contentType"
        
        public static let isAggregated: String =
            "com.marcuszhou.nineanimator.providerparser.DummyParser.option.isAggregated"
        
        public static let headers: String = "com.marcuszhou.nineanimator.providerparser.DummyParser.option.headers"
    }
    
    public func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
