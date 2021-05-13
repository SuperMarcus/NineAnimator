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
import SwiftSoup

public struct Episode {
    public let link: EpisodeLink
    public let target: URL
    
    public var name: String { link.name }
    public var parentLink: AnimeLink { link.parent }
    public var referer: String
    public var userInfo: [String: Any]
    
    public var nativePlaybackSupported: Bool {
        guard let serverName = parent.servers[link.server] else { return false }
        return source.suggestProvider(episode: self, forServer: link.server, withServerName: serverName) != nil
    }
    
    public var progress: Double { parent.trackingContext.playbackProgress(for: link) }
    
    public func update(progress: Float) { NineAnimator.default.user.update(progress: progress, for: link) }
    
    public var source: Source { parent.source }
    
    public let parent: Anime
    
    /// The tracking content for the episode
    public var trackingContext: TrackingContext {
        parent.trackingContext
    }
    
    public init(_ link: EpisodeLink, target: URL, parent: Anime, referer: String? = nil, userInfo: [String: Any] = [:]) {
        self.link = link
        self.target = target
        self.parent = parent
        self.referer = referer ?? parent.link.link.absoluteString
        self.userInfo = userInfo
    }
    
    public func retrive(forPurpose purpose: VideoProviderParser.Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask? {
        guard let serverName = parent.servers[link.server],
            let provider = source.suggestProvider(episode: self, forServer: link.server, withServerName: serverName) else {
            handler(nil, NineAnimatorError.providerError("no parser found for server \(link.server)"))
            return nil
        }
        
        return provider.parse(
            episode: self,
            with: source.retriverSession,
            forPurpose: purpose,
            onCompletion: handler
        )
    }
    
    public func next(onCompletion handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask? {
        guard let episodesQueue = parent.episodes[link.server], episodesQueue.count > 1 else {
            handler(nil, NineAnimatorError.lastItemInQueueError)
            return nil
        }
        
        Log.info("Looking for the next episode")
        
        for offset in 1..<episodesQueue.count where episodesQueue[offset - 1] == link {
            let nextEpisodeLink = episodesQueue[offset]
            return parent.episode(with: nextEpisodeLink, onCompletion: handler)
        }
        
        Log.info("This is the last episode")
        
        handler(nil, NineAnimatorError.lastItemInQueueError)
        return nil
    }
}
