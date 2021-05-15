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
import NineAnimatorCommon

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class NASourceAnimeKisa: BaseSource, Source, PromiseSource {
    var name: String { "animekisa.tv" }
    
    var aliases: [String] { [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "AnimeKisa Site Icon") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "AnimeKisa Site Icon") }
    #endif
    
    var siteDescription: String {
        "AnimeKisa is a free, ads-free, and HD anime streaming platform. NineAnimator has experimental support for this website."
    }
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.english
    }
    
    override var endpoint: String { "https://animekisa.tv" }
    
    override required init(with parent: NineAnimator) {
        super.init(with: parent)
        
        // Setup Kingfisher request modifier
        setupGlobalRequestModifier()
    }
    
    override func recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
        anime.servers.keys.contains("fembed") ? "fembed" : super.recommendServer(for: anime)
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        if server == "adless" { return VideoProviderRegistry.default.provider(DummyParser.self) }
        return VideoProviderRegistry.default.provider(for: name)
    }
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        .fail()
    }
}

// MARK: - Experimental Subsite
extension NASourceAnimeKisa {
    /// Experimental sub-site source for AnimeKisa
    ///
    /// Contributed by [Awsomedude](https://github.com/Awsomedude)
    class ExperimentalSource: NASourceAnimeKisa {
        override var name: String {
            "\u{0068}\u{0065}\u{006e}\u{0074}\u{0061}\u{0069}\u{006b}\u{0069}\u{0073}\u{0061}\u{002e}\u{0063}\u{006f}\u{006d}"
        }
        
        override var aliases: [String] { [] }
        
        override var siteDescription: String {
            "\u{0048}\u{0065}\u{006e}\u{0074}\u{0061}\u{0069}\u{004b}\u{0069}\u{0073}\u{0061} "
            + "\u{0069}\u{0073} \u{0061} \u{0066}\u{0072}\u{0065}\u{0065}\u{002c} "
            + "\u{0061}\u{0064}\u{0073}\u{002d}\u{0066}\u{0072}\u{0065}\u{0065}\u{002c} "
            + "\u{0061}\u{006e}\u{0064} \u{0048}\u{0044} \u{0068}\u{0065}\u{006e}\u{0074}\u{0061}\u{0069} "
            + "\u{0073}\u{0074}\u{0072}\u{0065}\u{0061}\u{006d}\u{0069}\u{006e}\u{0067} "
            + "\u{0070}\u{006c}\u{0061}\u{0074}\u{0066}\u{006f}\u{0072}\u{006d}\u{002e} "
            + "\u{0057}\u{0072}\u{0069}\u{0074}\u{0074}\u{0065}\u{006e} \u{0062}\u{0079} "
            + "\u{004a}\u{0061}\u{0063}\u{006b}\u{005f}\u{002c} \u{0074}\u{0072}\u{0069}\u{0062}\u{0075}\u{0074}\u{0065} "
            + "\u{0074}\u{006f} \u{0048}\u{006f}\u{006d}\u{0075}\u{0072}\u{0061} \u{0026} "
            + "\u{0055}\u{0074}\u{0074}\u{0069}\u{0079}\u{0061}\u{005f}\u{002e}"
        }
        
        override var endpoint: String {
            "\u{0068}\u{0074}\u{0074}\u{0070}\u{0073}\u{003a}\u{002f}\u{002f}\u{0068}\u{0065}\u{006e}\u{0074}\u{0061}\u{0069}\u{006b}\u{0069}\u{0073}\u{0061}\u{002e}\u{0063}\u{006f}\u{006d}"
        }
        
        override var isEnabled: Bool { false }
    }
}
