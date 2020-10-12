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

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import Foundation

class NASourceNineAnime: BaseSource, Source, PromiseSource {
    let name: String = "9anime.ru"
    
    var aliases: [String] { [] }
    
    override var endpoint: String { self._cachedDescriptor?.currentHost ?? "https://www12.9anime.ru" }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "9anime Site Icon") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "9anime Site Icon") }
    #endif
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.romaji
    }
    
    var siteDescription: String {
        "9anime is a popular free anime streaming website. NineAnimator's support for 9anime may be limited."
    }
    
    private var _cachedDescriptor: SourceDescriptor?
    
    override init(with parent: NineAnimator) {
        super.init(with: parent)
        self.setupGlobalRequestModifier()
    }
}

// MARK: - Protocol Impl
extension NASourceNineAnime {
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        VideoProviderRegistry.default.provider(for: name) ?? VideoProviderRegistry.default.provider(for: server)
    }
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        .fail()
    }
}

// MARK: - Definitions
extension NASourceNineAnime {
    /// Known hosts where 9anime stores their static assets
    var possibleStaticAssetHosts: [String] {
        [
            "static.9anime.ru",
            "static.9anime.to",
            "static.9anime.live"
        ]
    }
    
    var fallbackEndpoint: String {
        "https://www12.9anime.ru"
    }
    
    /// Request the source descriptor object
    func requestDescriptor() -> NineAnimatorPromise<SourceDescriptor> {
        // Serve cached descriptor is possible
        if let cached = self._cachedDescriptor {
            return .success(cached)
        }
        
        return requestUncachedDescriptor().then {
            self._cachedDescriptor = $0
            return $0
        }
    }
}
