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

class NASourceAnimeUltima: BaseSource, Source, PromiseSource {
    var name: String { return "animeultima.eu" }
    
#if canImport(UIKit)
    var siteLogo: UIImage { return #imageLiteral(resourceName: "AnimeUltima Site Logo") }
#elseif canImport(AppKit)
    var siteLogo: NSImage { return #imageLiteral(resourceName: "AnimeUltima Site Logo") }
#endif
    
    var siteDescription: String {
        return "AnimeUltima is a free anime streaming website with many self-hosted servers. This website is guarded by Cloudflare; you may be require to verify your identity manually."
    }
    
    override var endpoint: String { return "https://www10.animeultima.eu" }
    
    lazy var _auEngineParser = AUEngineParser(self)
    lazy var _fastStreamParser = FastStreamParser(self)
    
    func link(from url: URL) -> NineAnimatorPromise<AnyLink> {
        return .fail(.unknownError)
    }
    
    override func canHandle(url: URL) -> Bool {
        return false
    }
    
    override func recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
        let preferencesTable = [
            "faststream": 1000,
            "auengine": 900,
            "rapid video": 800
        ]
        
        let serverPreferencesMap = anime.servers.mapValues {
            serverName -> Int in
            let matchingKey = serverName.lowercased()
            for (key, piority) in preferencesTable {
                if key.lowercased().hasSuffix(matchingKey) {
                    return piority
                }
            }
            return 500
        }
        
        if let preferredServer = serverPreferencesMap.max(by: { $0.value < $1.value })?.key {
            return preferredServer
        } else { return super.recommendServer(for: anime) }
    }
}
