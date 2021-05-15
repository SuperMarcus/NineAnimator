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

internal class DummySource: Source, PromiseSource {
    /// Shared instance of the summy source.
    internal static let sharedInstance = DummySource()
    
    // swiftlint:disable unavailable_function
    required init(with _: NineAnimator) {
        fatalError("Don't initialize a dummy. Use DummySource.sharedInstance instead.")
    }
    // swiftlint:enable unavailable_function

    private init() { }
}

// MARK: - Dummy Getters
internal extension DummySource {
    // Yes, this is a dummy
    var name: String { "I'm a Dummy" }
    var aliases: [String] { [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "Unknwon Square") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "Unknwon Square") }
    #endif
    
    var siteDescription: String {
        "No anime source has been registered with NineAnimator. Add a new source in the source manager."
    }
    
    var isEnabled: Bool { true }
    var retriverSession: Session { Session.default }
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> { \.default }
}

// MARK: - Dummy Methods
internal extension DummySource {
    func search(keyword: String) -> ContentProvider {
        StaticContentProvider(
            title: keyword,
            result: .failure(NineAnimatorError.searchError(Self.dummyMessage))
        )
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        nil
    }
    
    func canHandle(url: URL) -> Bool {
        false
    }
    
    func recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
        nil
    }
    
    func recommendServers(for anime: Anime, ofPurpose: VideoProviderParserParsingPurpose) -> [Anime.ServerIdentifier] {
        []
    }
    
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        .fail(.unknownError("No anime source has been registered"))
    }
    
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        .fail(.unknownError("No anime source has been registered"))
    }
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        .fail(.unknownError("No anime source has been registered"))
    }
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        .fail(.unknownError("No anime source has been registered"))
    }
}

fileprivate extension DummySource {
    static let dummyMessage = "No anime source has been registered"
}
