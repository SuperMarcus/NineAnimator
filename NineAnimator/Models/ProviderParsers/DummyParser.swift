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

import Alamofire
import Foundation

/**
 A passthrough parser that passes the target url of the anime as the playback media
 */
class DummyParser: VideoProviderParser {
    func parse(episode: Episode, with session: SessionManager, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let dummyTask = NineAnimatorMultistepAsyncTask()
        
        DispatchQueue.main.async {
            handler(BasicPlaybackMedia(
                url: episode.target,
                parent: episode,
                contentType: "video/mp4",
                headers: [ "Referer": episode.link.parent.link.absoluteString ],
                isAggregated: false
            ), nil)
        }
        
        return dummyTask
    }
}
