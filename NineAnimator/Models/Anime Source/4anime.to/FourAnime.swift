//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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

class NASourceFourAnime: BaseSource, Source, PromiseSource {
    var name: String { return "4anime.to" }
    
    var aliases: [String] { return [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { return #imageLiteral(resourceName: "4anime Site Icon") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { return #imageLiteral(resourceName: "4anime Site Icon") }
    #endif
    
    var siteDescription: String {
        return "4anime is a popular free anime streaming website funded by donations. This website is guarded by Cloudflare; you may be asked to verify your identity."
    }
    
    class var FourAnimeStream: Anime.ServerIdentifier {
        return "4anime"
    }
    
    override var endpoint: String { return "https://4anime.to" }
    
    override init(with parent: NineAnimator) {
        super.init(with: parent)
        
        // Setup Kingfisher request modifier
        setupGlobalRequestModifier()
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        return server == NASourceFourAnime.FourAnimeStream
            ? DummyParser.registeredInstance : nil
    }
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        return .fail()
    }
}
