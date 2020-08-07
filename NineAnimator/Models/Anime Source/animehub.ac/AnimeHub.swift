//
//  AnimeHub.swift
//  NineAnimator
//
//  Created by Uttiya Dutta on 2020-08-07.
//  Copyright © 2020 Marcus Zhou. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class NASourceAnimeHub: BaseSource, Source, PromiseSource {
    var name: String { "animehub.ac" }
    
    var aliases: [String] { [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "4anime Site Icon") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "MonosChinos.png") }
    #endif

    var siteDescription: String {
        "AnimeHub has many servers to choose from. NineAnimator has experimental support for this!"
    }
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.romaji
    }
    
    func search(keyword: String) -> ContentProvider {
        
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        
    }
    
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        
    }
}
