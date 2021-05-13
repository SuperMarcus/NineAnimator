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
@objc protocol NACoreEngineExportsEpisodeProtocol: JSExport {
    var link: NACoreEngineExportsEpisodeLink { get }
    var target: String { get }
    var name: String { get }
    var parentLink: NACoreEngineExportsAnimeLink { get }
    var parent: NACoreEngineExportsAnime { get }
    
    var userInfo: [String: Any]? { get set }
    var referer: String? { get set }
    
    init?(episodeLink: NACoreEngineExportsEpisodeLink?, targetURLString: String?, parentAnime: NACoreEngineExportsAnime?, referer: String?, userInfo: [String: Any]?)
}

@available(iOS 13, *)
@objc class NACoreEngineExportsEpisode: NSObject, NACoreEngineExportsEpisodeProtocol {
    dynamic var link: NACoreEngineExportsEpisodeLink {
        .init(underlyingEpisodeObject.link)
    }
    
    dynamic var target: String {
        underlyingEpisodeObject.target.absoluteString
    }
    
    dynamic var name: String {
        underlyingEpisodeObject.name
    }
    
    dynamic var parentLink: NACoreEngineExportsAnimeLink {
        .init(underlyingEpisodeObject.parentLink)
    }
    
    dynamic var parent: NACoreEngineExportsAnime {
        .init(underlyingEpisodeObject.parent)
    }
    
    dynamic var userInfo: [String: Any]? {
        get {
            underlyingEpisodeObject.userInfo
        }
        set {
            if let engine = NACoreEngine.current() {
                underlyingEpisodeObject.userInfo = engine.validateValue(newValue) ?? [:]
            }
        }
    }
    
    dynamic var referer: String? {
        get {
            underlyingEpisodeObject.referer
        }
        set {
            underlyingEpisodeObject.referer = newValue ?? underlyingEpisodeObject.parent.link.link.absoluteString
        }
    }
    
    var underlyingEpisodeObject: Episode
    
    init(_ nativeEpisode: Episode) {
        self.underlyingEpisodeObject = nativeEpisode
        super.init()
    }
    
    required init?(episodeLink: NACoreEngineExportsEpisodeLink?, targetURLString: String?, parentAnime: NACoreEngineExportsAnime?, referer: String?, userInfo: [String: Any]?) {
        guard let engine = NACoreEngine.current() else {
            Log.error("[NACoreEngineExportsEpisode] Cannot instantiate the episode object outside a JavaScript execution context.")
            return nil
        }
        
        guard let episodeLink = episodeLink,
              let nativeEpisodeLink = episodeLink.nativeEpisodeLink else {
            engine.raiseErrorInContext(NineAnimatorError.argumentError("The episode link is either undefined or invalid."))
            return nil
        }
        
        guard let parentAnime = parentAnime?.underlyingAnimeObject else {
            engine.raiseErrorInContext(NineAnimatorError.argumentError("The parent anime object is either undefined or invalid."))
            return nil
        }
        
        guard let targetURLString = targetURLString,
              let targetURL = URL(protocolRelativeString: targetURLString, relativeTo: parentAnime.link.link) else {
            engine.raiseErrorInContext(NineAnimatorError.argumentError("The target URL string is either undefined or invalid."))
            return nil
        }
        
        self.underlyingEpisodeObject = .init(
            nativeEpisodeLink,
            target: targetURL,
            parent: parentAnime,
            referer: referer,
            userInfo: engine.validateValue(userInfo) ?? [:]
        )
        
        super.init()
    }
}
