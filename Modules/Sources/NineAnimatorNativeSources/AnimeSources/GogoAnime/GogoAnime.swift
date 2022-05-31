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
import SwiftSoup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class NASourceGogoAnime: BaseSource, Source, PromiseSource {
    var name: String { "gogoanime.gg" }
    
    var aliases: [String] { [ "gogoanime.tv" ] }
    
#if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "GogoAnime Site Icon") }
#elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "GogoAnime Site Icon") }
#endif
    
    var siteDescription: String {
        "GogoAnime is a free anime streaming website. NineAnimator has fairly good support for this website."
    }
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.english
    }

    override var endpoint: String { "https://www2.gogoanime.video" }

    let ajaxEndpoint = URL(string: "https://ajax.apimovie.xyz")!

    func search(keyword: String) -> ContentProvider {
        GogoContentProvider(query: keyword, parent: self)
    }

    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        VideoProviderRegistry.default.provider(for: name)
    }
    
    override required init(with parent: NineAnimator) {
        super.init(with: parent)
    }
}
