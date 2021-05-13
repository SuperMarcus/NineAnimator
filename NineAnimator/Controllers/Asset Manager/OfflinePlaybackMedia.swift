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

import AVKit
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources
import OpenCastSwift

/// The playback media for offline content
struct OfflinePlaybackMedia: PlaybackMedia {
    // The link to the episode
    let link: EpisodeLink
    
    let isAggregated: Bool
    
    let url: URL
    
    let trackingContext: TrackingContext
    
    // All of the followings are generated from the above content
    
    var name: String { link.name }
    
    // AVPlayerItem
    var avPlayerItem: AVPlayerItem
    
    // Google Cast is not supported by offline playback media
    // May be implemented later
    var castMedia: CastMedia? { nil }
    
    // Do not re-download OfflinePlaybackMedia
    var urlRequest: URLRequest? { nil }
    
    /// Initialize the offline playback media with url
    init(link: EpisodeLink, isAggregated: Bool, url: URL) {
        self.link = link
        self.isAggregated = isAggregated
        self.url = url
        self.avPlayerItem = AVPlayerItem(url: url)
        self.trackingContext = NineAnimator.default.trackingContext(for: link.parent)
    }
    
    /// Initialize the offline playback media with AVURLAsset
    init(link: EpisodeLink, isAggregated: Bool, asset: AVURLAsset) {
        self.link = link
        self.isAggregated = isAggregated
        self.url = asset.url
        self.avPlayerItem = AVPlayerItem(asset: asset)
        self.trackingContext = NineAnimator.default.trackingContext(for: link.parent)
    }
}
