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
import JavaScriptCore

@available(iOS 13, *)
@objc protocol NACoreEngineExportsEpisodeLinkProtocol: JSExport {
    var identifier: String { get set }
    var name: String { get set }
    var server: String { get set }
    var parent: NACoreEngineExportsAnimeLink { get set }
    
    init(identifier: String, name: String, server: String, parent: NACoreEngineExportsAnimeLink?)
}

@available(iOS 13, *)
@objc class NACoreEngineExportsEpisodeLink: NSObject, NACoreEngineExportsEpisodeLinkProtocol {
    dynamic var identifier: String
    dynamic var name: String
    dynamic var server: String
    dynamic var parent: NACoreEngineExportsAnimeLink
    
    /// Attempts to convert the object to a native EpisodeLink
    var nativeEpisodeLink: EpisodeLink? {
        if let nativeParent = parent.nativeAnimeLink {
            return EpisodeLink(
                identifier: self.identifier,
                name: self.name,
                server: self.server,
                parent: nativeParent
            )
        }
        
        return nil
    }
    
    required init(identifier: String, name: String, server: String, parent: NACoreEngineExportsAnimeLink?) {
        self.identifier = identifier
        self.name = name
        self.server = server
        self.parent = parent ?? .init()
        super.init()
    }
    
    init(_ episodeLink: EpisodeLink) {
        self.identifier = episodeLink.identifier
        self.name = episodeLink.name
        self.server = episodeLink.server
        self.parent = NACoreEngineExportsAnimeLink(episodeLink.parent)
        super.init()
    }
}
