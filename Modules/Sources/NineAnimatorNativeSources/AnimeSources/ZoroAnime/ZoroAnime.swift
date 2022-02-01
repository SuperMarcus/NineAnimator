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

class NASourceZoroAnime: BaseSource, Source, PromiseSource {
    var name: String { "zoro.to" }
    
    var aliases: [String] { [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "Zoro Site Icon") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "Zoro Site Icon") }
    #endif

    var siteDescription: String {
        "Zoro is a popular ads-free anime streaming websites that allows you to stream subbed in multiple langagues or dubbed in ultra HD quality. NineAnimator has experimental support for this website."
    }
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.romaji
    }
    
    override var endpoint: String { "https://zoro.to" }
    let ajaxEndpoint = URL(string: "https://zoro.to/ajax/")!

    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        switch server {
        case _ where server.contains("VidStreaming"),
             _ where server.contains("Vidcloud"):
            return VideoProviderRegistry.default.provider(for: "RapidCloud")
        case _ where server.contains("Streamsb"):
            return VideoProviderRegistry.default.provider(for: "Streamsb")
        case _ where server.contains("Streamtape"):
            return VideoProviderRegistry.default.provider(for: "Streamtape")
        default:
            return VideoProviderRegistry.default.provider(for: name) ?? VideoProviderRegistry.default.provider(for: server)
        }
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
