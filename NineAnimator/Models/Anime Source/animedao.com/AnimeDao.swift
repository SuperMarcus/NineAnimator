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

class NASourceAnimeDao: BaseSource, Source, PromiseSource {
    var name: String { return "animedao.com" }
    
    var aliases: [String] { return [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { return #imageLiteral(resourceName: "4anime Site Icon") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { return #imageLiteral(resourceName: "4anime Site Icon") }
    #endif
    
    var siteDescription: String {
        return "animedao.com allows you to freely stream anime and movies with subtitles in SD and HD. NineAnimator has experimental support for this website."
    }
    
    override var endpoint: String { return "https://animedao.com" }
    
    override init(with parent: NineAnimator) {
        super.init(with: parent)
        
        // Setup Kingfisher request modifier
        setupGlobalRequestModifier()
    }
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        return .fail()
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        var modifyingServerIdentifier = server
        _ = modifyingServerIdentifier.removeFirst()
        return VideoProviderRegistry.default.provider(for: modifyingServerIdentifier)
    }
    
    override func canHandle(url: URL) -> Bool {
        return false
    }
}
