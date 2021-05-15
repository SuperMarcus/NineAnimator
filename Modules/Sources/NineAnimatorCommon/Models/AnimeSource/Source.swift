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
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Representing an anime source website supported by NineAnimator
public protocol Source: AnyObject {
    /// The name of the source website
    var name: String { get }
    
    /// Aliases of the source
    var aliases: [String] { get }
    
#if canImport(UIKit)
    /// The logo of the website
    var siteLogo: UIImage { get }
#elseif canImport(AppKit)
    /// The logo of the website
    var siteLogo: NSImage { get }
#endif
    
    /// A brief description of the website
    var siteDescription: String { get }
    
    /// If the source is available
    var isEnabled: Bool { get }
    
    /// The Alamofire session manager for retriving contents
    /// from the represented website.
    var retriverSession: Session { get }
    
    /// The preferred anime title variant to be used to perform search in this source
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> { get }
    
    init(with parent: NineAnimator)
    
    func featured(_ handler: @escaping NineAnimatorCallback<FeaturedContainer>) -> NineAnimatorAsyncTask?
    
    func anime(from link: AnimeLink, _ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask?
    
    func episode(from link: EpisodeLink, with anime: Anime, _ handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask?
    
    func search(keyword: String) -> ContentProvider
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser?
    
    func link(from url: URL, _ handler: @escaping NineAnimatorCallback<AnyLink>) -> NineAnimatorAsyncTask?
    
    /// Return true if this source supports translating contents
    /// from the provided URL
    func canHandle(url: URL) -> Bool
    
    /// Recommend a preferred server for the anime object
    func recommendServer(for anime: Anime) -> Anime.ServerIdentifier?
    
    /// Recommend a list of servers (ordered from the best to the worst) for a particular purpose
    func recommendServers(for anime: Anime, ofPurpose: VideoProviderParser.Purpose) -> [Anime.ServerIdentifier]
}
