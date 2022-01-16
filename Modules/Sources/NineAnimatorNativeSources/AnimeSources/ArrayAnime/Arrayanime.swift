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

class NASourceArrayanime: BaseSource, Source, PromiseSource {
    var name: String { "arrayanime.com" }
    
    var aliases: [String] { [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "Arrayanime Site Icon") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "Arrayanime Site Icon") }
    #endif

    var siteDescription: String {
        "ArrayAnime allows you to stream subtitled, dubbed, chinese anime and movies in HD. NineAnimator has experimental support for this website."
    }
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.romaji
    }
    
    // Disable due to Arrayanime constantly changing API domain
    override var isEnabled: Bool { false }
    
    override var endpoint: String { "https://arrayanime.com" }
    
    let searchEndpoint = URL(string: "https://t-arrayapi.vercel.app/api/")!
    
    let animeDetailsEndpoint = URL(string: "https://apitest-mu.vercel.app/api/")!
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        DummyParser.registeredInstance
    }
    
    override func recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
        recommendServers(for: anime, ofPurpose: .playback).first
    }

    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        .fail()
    }
    
    override required init(with parent: NineAnimator) {
        super.init(with: parent)
    }
}
