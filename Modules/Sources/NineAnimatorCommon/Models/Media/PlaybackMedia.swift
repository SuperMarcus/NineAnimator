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
import AVKit
import Foundation
import OpenCastSwift

/// Representing a playable media
public protocol PlaybackMedia {
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

// A shortcut for setting and retriving playback progress
public extension PlaybackMedia {
    var progress: Double {
        get { link.playbackProgress }
        set {
            let trackingContext = NineAnimator.default.trackingContext(for: link.parent)
            trackingContext.update(progress: newValue, forEpisodeLink: link)
        }
    }
}

/// Key for options in AVAsset to pass in request headers
public let AVURLAssetHTTPHeaderFieldsKey = "AVURLAssetHTTPHeaderFieldsKey"
