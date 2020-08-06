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

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class NASourceTheWatchCartoonOnline: BaseSource, Source, PromiseSource {
    var name: String { "TheWatchCartoonOnline.tv" }
    
    var aliases: [String] { [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage {#imageLiteral(resourceName: "TheWatchCartoonOnline.png")}
    #elseif canImport(AppKit)
    var siteLogo: NSImage {#imageLiteral(resourceName: "TheWatchCartoonOnline.png")}
    #endif
    
    var siteDescription: String {
        "TheWatchCartoonOnline is a free, ads-free, and HD anime and Cartoons streaming platform. NineAnimator has experimental support for this website."
    }
    
    class var NASourceTheWatchCartoonOnlineStream: Anime.ServerIdentifier {
        "TheWatchCartoonOnline"
    }
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.english
    }
    
    override var endpoint: String { "https://thewatchcartoononline.tv" }
    
    override init(with parent: NineAnimator) {
        super.init(with: parent)
        
        // Setup Kingfisher request modifier
        setupGlobalRequestModifier()
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        server == NASourceTheWatchCartoonOnline.NASourceTheWatchCartoonOnlineStream
            ? DummyParser.registeredInstance : nil
    }
    
    override func recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
        recommendServers(for: anime, ofPurpose: .playback).first
    }
    
    override func recommendServers(for anime: Anime, ofPurpose purpose: VideoProviderParserParsingPurpose) -> [Anime.ServerIdentifier] {
        anime.servers.keys.contains(NASourceTheWatchCartoonOnline.NASourceTheWatchCartoonOnlineStream)
            ? [NASourceTheWatchCartoonOnline.NASourceTheWatchCartoonOnlineStream] : []
    }
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        .fail()
    }
}
