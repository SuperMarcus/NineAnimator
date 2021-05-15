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

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import NineAnimatorCommon

class NASourceAniwatch: BaseSource, Source, PromiseSource {
    var name: String { "aniwatch.me" }
    
    var aliases: [String] { [] }
    
    #if canImport(UIKit)
    var siteLogo: UIImage { #imageLiteral(resourceName: "Aniwatch Site Icon") }
    #elseif canImport(AppKit)
    var siteLogo: NSImage { #imageLiteral(resourceName: "Aniwatch Site Icon") }
    #endif

    var siteDescription: String {
        "Aniwatch is a fast source, and provides alot of anime information, however it requires an account to use."
    }
    
    var preferredAnimeNameVariant: KeyPath<ListingAnimeName, String> {
        \.romaji
    }
    
    override var endpoint: String { "https://aniwatch.me" }
    
    /*let ajexEndpoint = URL(string: "https://aniwatch.me/api/ajax/APIHandle")!
    
    lazy var XSRFRequestModifier: NARequestAdapter = XSRFTokenModifier(parent: self)
    lazy var AuthRequestModifier: NARequestAdapter = AuthSessionModifier(parent: self)
    
    override init(with parent: NineAnimator) {
        super.init(with: parent)
        requestManager.enqueueAdapter(XSRFRequestModifier)
        requestManager.enqueueAdapter(AuthRequestModifier)
    }*/
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        nil
        // NASourceAniwatch.knownServers.keys.contains(server) ? DummyParser.registeredInstance : nil
    }
    
    override func recommendServers(for anime: Anime, ofPurpose purpose: VideoProviderParserParsingPurpose) -> [Anime.ServerIdentifier] {
        []
        /*if purpose == .googleCast { return [] }
        return [ "ensub", "endub", "desub", "dedub" ]*/
    }
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        .fail()
    }
    
    override var isEnabled: Bool { false }
    
    override required init(with parent: NineAnimator) {
        super.init(with: parent)
    }
}
