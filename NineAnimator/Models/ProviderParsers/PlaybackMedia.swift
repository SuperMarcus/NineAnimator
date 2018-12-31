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
import AVKit
import Foundation
import OpenCastSwift

protocol PlaybackMedia {
    var avPlayerItem: AVPlayerItem { get }
    var castMedia: CastMedia? { get }
    var parent: Episode { get }
}

struct BasicPlaybackMedia: PlaybackMedia {
    let url: URL
    let parent: Episode
    let contentType: String
    let headers: HTTPHeaders
    
    var avPlayerItem: AVPlayerItem {
        return AVPlayerItem(url: url, headers: headers)
    }
    
    var castMedia: CastMedia? {
        return CastMedia(
            title: parent.name,
            url: url,
            poster: parent.link.parent.image,
            contentType: contentType,
            streamType: .buffered,
            autoplay: true,
            currentTime: 0
        )
    }
}

//A shortcut for setting and retriving playback progress
extension PlaybackMedia {
    var progress: Float {
        get { return parent.progress }
        set { parent.update(progress: newValue) }
    }
}
