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

class NASourceAnimeSaturn: BaseSource, Source, PromiseSource {
    var name: String { "animesaturn.com" }
    
    var aliases: [String] { [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "AnimeSaturn Site Icon") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "AnimeSaturn Site Icon") }
    #endif
    var siteDescription: String {
        "AnimeSaturn è un server italiano. AnimeSaturn is a free website that provides Italian subtitled anime."
    }
    
    class var AnimeSaturnStream: Anime.ServerIdentifier {
        "AnimeSaturn"
    }
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.english
    }
    
    override var endpoint: String { "https://animesaturn.com" }
    
    override required init(with parent: NineAnimator) {
        super.init(with: parent)
        
        // Setup Kingfisher request modifier
        setupGlobalRequestModifier()
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        server == NASourceAnimeSaturn.AnimeSaturnStream
            ? DummyParser.registeredInstance : nil
    }
    
    override func recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
        recommendServers(for: anime, ofPurpose: .playback).first
    }
    
    override func recommendServers(for anime: Anime, ofPurpose purpose: VideoProviderParserParsingPurpose) -> [Anime.ServerIdentifier] {
        anime.servers.keys.contains(NASourceAnimeSaturn.AnimeSaturnStream)
            ? [NASourceAnimeSaturn.AnimeSaturnStream] : []
    }
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        .fail()
    }
}
