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
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources

@available(iOS 13, *)
@objc protocol NACoreEngineExportsAnimeLinkProtocol: JSExport {
    var link: String { get set }
    var image: String { get set }
    var title: String { get set }
    var source: String { get set }
    
    init(title: String, link: String, image: String, sourceName: String)
}

/// Wrapper object for the native AnimeLink
@available(iOS 13, *)
@objc class NACoreEngineExportsAnimeLink: NSObject, NACoreEngineExportsAnimeLinkProtocol {
    dynamic var link: String
    dynamic var image: String
    dynamic var title: String
    dynamic var source: String
    
    /// Attempt to convert the object to a native AnimeLink.
    var nativeAnimeLink: AnimeLink? {
        if let linkUrl = URL(string: self.link),
           let imageUrl = URL(string: self.image),
           let sourceObject = NineAnimator.default.source(with: self.source) {
            return AnimeLink(
                title: self.title,
                link: linkUrl,
                image: imageUrl,
                source: sourceObject
            )
        }
        
        Log.debug("[NineAnimatorCore.AnimeLink] Conversion from %@ to native AnimeLink failed.", self.description)
        return nil
    }
    
    override var description: String {
        String(
            format: "NineAnimatorCore.AnimeLink(title=%@, link=%@, image=%@, source=%@)",
            self.link,
            self.image,
            self.title,
            self.source
        )
    }
    
    required init(title: String, link: String, image: String, sourceName: String) {
        self.link = link
        self.image = image
        self.title = title
        self.source = sourceName
        super.init()
    }
    
    init(_ link: AnimeLink) {
        self.link = link.link.absoluteString
        self.image = link.image.absoluteString
        self.title = link.title
        self.source = link.source.name
        super.init()
    }
    
    override init() {
        self.link = ""
        self.image = ""
        self.title = ""
        self.source = ""
        super.init()
    }
}
