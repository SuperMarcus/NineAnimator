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

/// A media container for retrieved media
public struct BasicPlaybackMedia: PlaybackMedia {
    public let url: URL
    public let parent: Episode
    public let contentType: String
    public let headers: [String: String]
    public let isAggregated: Bool
    
    public init(url: URL, parent: Episode, contentType: String, headers: [String: String], isAggregated: Bool) {
        self.url = url
        self.parent = parent
        self.contentType = contentType
        self.headers = headers
        self.isAggregated = isAggregated
    }
}

public extension BasicPlaybackMedia {
    var avPlayerItem: AVPlayerItem {
        AVPlayerItem(url: url, headers: headers)
    }
    
    var link: EpisodeLink { parent.link }
    
    var name: String { parent.name }
    
    var castMedia: CastMedia? {
        CastMedia(
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
