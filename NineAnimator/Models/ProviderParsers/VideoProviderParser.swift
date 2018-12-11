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

import UIKit
import Alamofire
import AVKit

protocol VideoProviderParser {
    func parse(episode: Episode, with: SessionManager, onCompletion: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask
}

class VideoProviderRegistry {
    static let `default`: VideoProviderRegistry = {
        let defaultProvider = VideoProviderRegistry()
        
        defaultProvider.register(MyCloudParser(), forServer: "28")
        defaultProvider.register(RapidVideoParser(), forServer: "33")
        defaultProvider.register(StreamangoParser(), forServer: "34")
        
        return defaultProvider
    }()
    
    private var providers = [(server: Anime.ServerIdentifier, provider: VideoProviderParser)]()
    
    func register(_ provider: VideoProviderParser, forServer server: Anime.ServerIdentifier) {
        providers.append((server, provider))
    }
    
    func provider(for server: Anime.ServerIdentifier) -> VideoProviderParser? {
        return (providers.first { $0.server == server })?.provider
    }
}
