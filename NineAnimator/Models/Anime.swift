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

extension NineAnimator {
    func anime(with link: AnimeLink, onCompletion handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask? {
        return link.source.anime(from: link, handler)
    }
}

struct Anime {
    typealias ServerIdentifier = String
    typealias EpisodeIdentifier = String
    typealias AnimeIdentifier = String
    typealias EpisodeLinksCollection = [EpisodeLink]
    
    let link: AnimeLink
    let servers: [ServerIdentifier: String]
    let episodes: [ServerIdentifier: EpisodeLinksCollection]
    let description: String
    
    var currentServer: ServerIdentifier
    
    var source: Source { return link.source }
    
    init(_ link: AnimeLink,
         description: String,
         on servers: [ServerIdentifier: String],
         episodes: [ServerIdentifier: EpisodeLinksCollection]) {
        self.link = link
        self.servers = servers
        self.episodes = episodes
        self.currentServer = servers.first!.key
        self.description = description
    }
    
    func episode(with link: EpisodeLink, onCompletion handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask? {
        return source.episode(from: link, with: self, handler)
    }
}
