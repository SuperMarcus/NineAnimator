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
import NineAnimatorCommon

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Made with love by Jack_ the Awsomedude
class NASourceHAnime: BaseSource, Source, PromiseSource {
    var name: String { "hanime.tv" }
    
    var aliases: [String] { [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "HAnime Site Icon") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "HAnime Site Icon") }
    #endif
    
    var siteDescription: String {
        "Watch Free Hentai Video Streams Online in 720p, 1080p HD. Tribute to Ruii and marcuszhou."
    }
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.romaji
    }
    
    override var endpoint: String { "https://hanime.tv/" }
    
    override var isEnabled: Bool { NineAnimator.default.user.allowNSFWContent && NineAnimator.default.user.enableExperimentalSources }
    
    // From twist.moe thanks Marcus
    static let animeObjMatchingRegex = try! NSRegularExpression(pattern: "window\\.__NUXT__=([^<]+)", options: [])
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        DummyParser.registeredInstance
    }
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        .fail()
    }
    
    override required init(with parent: NineAnimator) {
        super.init(with: parent)
    }
}
