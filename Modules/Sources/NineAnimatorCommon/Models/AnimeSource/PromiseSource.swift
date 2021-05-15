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

import Foundation

public protocol PromiseSource {
    func featured() -> NineAnimatorPromise<FeaturedContainer>
    
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime>
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode>
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink>
}

// Implement the Source methods
public extension PromiseSource {
    func featured(_ handler: @escaping NineAnimatorCallback<FeaturedContainer>) -> NineAnimatorAsyncTask? {
        featured().handle(handler)
    }
    
    func anime(from link: AnimeLink, _ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask? {
        anime(from: link).handle(handler)
    }
    
    func episode(from link: EpisodeLink, with anime: Anime, _ handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask? {
        episode(from: link, with: anime).handle(handler)
    }
    
    func link(from url: URL, _ handler: @escaping NineAnimatorCallback<AnyLink>) -> NineAnimatorAsyncTask? {
        link(from: url).handle(handler)
    }
}
