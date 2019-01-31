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

/// Representing a playable media
protocol PlaybackMedia {
    /// Obtain the AVPlayerItem object for this asset
    var avPlayerItem: AVPlayerItem { get }
    
    /// Obtain the CastMedia object for this asset
    var castMedia: CastMedia? { get }
    
    /// Obtain the URLRequest for this asset
    var urlRequest: URLRequest? { get }
    
    /// The episode link that this playback media is referring to
    var link: EpisodeLink { get }
    
    /// Describing the episode
    var name: String { get }
    
    /// Specify if this media uses HLS/m3u8 playlist
    /// and should be preserved using AVAssetDownloadURLSession
    var isAggregated: Bool { get }
}

struct BasicPlaybackMedia: PlaybackMedia {
    let url: URL
    let parent: Episode
    let contentType: String
    let headers: HTTPHeaders
    let isAggregated: Bool
    
    var avPlayerItem: AVPlayerItem {
        return AVPlayerItem(url: url, headers: headers)
    }
    
    var link: EpisodeLink { return parent.link }
    
    var name: String { return parent.name }
    
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
    
    var urlRequest: URLRequest? {
        // Return nil on aggregated asset
        guard !isAggregated else { return nil }
        
        // Construct the URLRequest from the information provided
        return try? URLRequest(url: url, method: .get, headers: headers)
    }
}

//A shortcut for setting and retriving playback progress
extension PlaybackMedia {
    var progress: Float {
        get { return NineAnimator.default.user.playbackProgress(for: link) }
        set { NineAnimator.default.user.update(progress: newValue, for: link) }
    }
}
