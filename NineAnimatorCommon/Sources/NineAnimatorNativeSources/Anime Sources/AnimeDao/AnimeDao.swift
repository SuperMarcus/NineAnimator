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

class NASourceAnimeDao: BaseSource, Source, PromiseSource {
    var name: String { "animedao.to" }
    
    var aliases: [String] { [ "animedao.com" ] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "AnimeDao Site Logo") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "AnimeDao Site Logo") }
    #endif
    
    var siteDescription: String {
        "animedao.com allows you to stream subtitled anime and movies in SD and HD. NineAnimator has experimental support for this website."
    }
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.english
    }
    
    override var endpoint: String { "https://animedao.to" }
    
    static let animedaoStreamEndpoint = URL(string: "https://animedao24.stream")!
    
    var deprecatedHosts: [String] { [ "animedao.com" ] }
    
    required override init(with parent: NineAnimator) {
        super.init(with: parent)
        
        // Setup Kingfisher request modifier
        setupGlobalRequestModifier()
    }
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        .fail()
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        if episode.userInfo["I am dummy"] as? Bool == true {
            return DummyParser.registeredInstance
        }
        
        if let info = NASourceAnimeDao.knownServerMap[server] {
            return VideoProviderRegistry.default.provider(for: info.name)
        } else { return nil }
    }
    
    override func canHandle(url: URL) -> Bool {
        false
    }
}
