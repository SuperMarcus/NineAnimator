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
import AVKit
import OpenCastSwift
import Alamofire

protocol PlaybackMedia {
    var avPlayerItem: AVPlayerItem { get }
    var castMedia: CastMedia? { get }
}

struct BasicPlaybackMedia: PlaybackMedia {
    let playbackUrl: URL
    let customHeaders: Alamofire.HTTPHeaders
    let parent: Episode
    let contentType: String
    
    var avPlayerItem: AVPlayerItem {
        let asset = AVURLAsset(url: playbackUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": customHeaders])
        return AVPlayerItem(asset: asset)
    }
    
    var castMedia: CastMedia? {
        let media = CastMedia(
            title: parent.name,
            url: playbackUrl,
            poster: parent.link.parent.image,
            contentType: contentType,
            streamType: .buffered,
            autoplay: true,
            currentTime: 0)
        return media
    }
    
    init(_ url: URL, parent: Episode, contentType: String, headers: Alamofire.HTTPHeaders = [:]) {
        self.playbackUrl = url
        self.customHeaders = headers
        self.parent = parent
        self.contentType = contentType
    }
}
