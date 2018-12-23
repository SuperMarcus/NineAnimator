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
import Alamofire
import SwiftSoup
import AVKit

struct Episode {
    let link: EpisodeLink
    let target: URL
    
    var name: String { return link.name }
    var parentLink: AnimeLink { return link.parent }
    var referer: String
    
    var nativePlaybackSupported: Bool {
        guard let serverName = _parent.servers[link.server] else { return false }
        return source.suggestProvider(episode: self, forServer: link.server, withServerName: serverName) != nil
    }
    
    var progress: Float { return NineAnimator.default.user.playbackProgress(for: link) }
    
    func update(progress: Float){ NineAnimator.default.user.update(progress: progress, for: link) }
    
    var source: Source { return _parent.source }
    
    private var _parent: Anime
    
    init(_ link: EpisodeLink, target: URL, parent: Anime, referer: String? = nil) {
        self.link = link
        self.target = target
        self._parent = parent
        self.referer = referer ?? parent.link.link.absoluteString
    }
    
    func retrive(onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask? {
        guard let serverName = _parent.servers[link.server],
            let provider = source.suggestProvider(episode: self, forServer: link.server, withServerName: serverName) else {
            handler(nil, NineAnimatorError.providerError("no parser found for server \(link.server)"))
            return nil
        }
        
        return provider.parse(episode: self, with: source.retriverSession, onCompletion: handler)
    }
}
