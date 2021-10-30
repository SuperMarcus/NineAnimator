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

class NASourceAnimeWorld: BaseSource, Source, PromiseSource {
    var name: String { "animeworld.tv" }
    
    var aliases: [String] { [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "AnimeWorld Site Logo") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "AnimeWorld Site Logo") }
    #endif
    var siteDescription: String {
        "AnimeWorld è un server italiano. AnimeWorld is a free website that provides Italian subtitled anime."
    }
    
    class var AnimeWorldStream: Anime.ServerIdentifier {
        "AnimeWorld"
    }
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.english
    }
    
    override var endpoint: String { "https://www.animeworld.tv" }
    
    override required init(with parent: NineAnimator) {
        super.init(with: parent)
        
        // Setup Kingfisher request modifier
        setupGlobalRequestModifier()
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        server == NASourceAnimeWorld.AnimeWorldStream
            ? DummyParser.registeredInstance : nil
    }
    
    override func recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
        recommendServers(for: anime, ofPurpose: .playback).first
    }
    
    override func recommendServers(for anime: Anime, ofPurpose purpose: VideoProviderParserParsingPurpose) -> [Anime.ServerIdentifier] {
        anime.servers.keys.contains(NASourceAnimeWorld.AnimeWorldStream)
            ? [NASourceAnimeWorld.AnimeWorldStream] : []
    }
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        .fail()
    }
}
