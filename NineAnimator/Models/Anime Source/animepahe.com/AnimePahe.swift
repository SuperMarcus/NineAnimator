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

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class NASourceAnimePahe: BaseSource, Source, PromiseSource {
    var name: String { "animepahe.com" }
    
    var aliases: [String] { [] }
    
    var siteDescription: String {
        "AnimePahe is a free, donation based website that provides ad-less experience of streaming anime. NineAnimator has experimental support with this website."
    }
    
    override var endpoint: String {
        "https://animepahe.com"
    }
    
    var animeBaseUrl: URL {
        endpointURL.appendingPathComponent("anime")
    }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "AnimePahe Site Icon") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "AnimePahe Site Icon") }
    #endif
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.romaji
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        VideoProviderRegistry.default.provider(for: name)
    }
    
    override func canHandle(url: URL) -> Bool {
        let components = url.pathComponents
        return super.canHandle(url: url) &&
            components.count >= 3 &&
            (components[1] == "play" || components[1] == "anime")
    }
}
