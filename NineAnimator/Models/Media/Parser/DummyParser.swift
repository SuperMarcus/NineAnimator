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
import Foundation

/// A passthrough parser that passes the target url of the anime as the playback media
class DummyParser: VideoProviderParser {
    var aliases: [String] { return [] }
    
    func parse(episode: Episode, with session: SessionManager, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let dummyTask = AsyncTaskContainer()
        
        DispatchQueue.main.async {
            let options = episode.userInfo
            var isAggregatedAsset = false
            
            // Infer isAggregated from mime type
            if let contentType = options[Options.contentType] as? String {
                isAggregatedAsset = self.isAggregatedAsset(mimeType: contentType)
            }
            
            handler(BasicPlaybackMedia(
                url: episode.target,
                parent: episode,
                contentType: (options[Options.contentType] as? String) ?? "video/mp4",
                headers: [ "Referer": episode.link.parent.link.absoluteString ],
                isAggregated: (options[Options.isAggregated] as? Bool) ?? isAggregatedAsset
            ), nil)
        }
        
        return dummyTask
    }
    
    enum Options {
        static let contentType: String =
            "com.marcuszhou.nineanimator.providerparser.DummyParser.option.contentType"
        
        static let isAggregated: String =
            "com.marcuszhou.nineanimator.providerparser.DummyParser.option.isAggregated"
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        return true
    }
}
