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
@objc protocol NACoreEngineExportsPlaybackMediaProtocol: JSExport {
    var url: String { get }
    var parent: NACoreEngineExportsEpisode { get }
    var link: NACoreEngineExportsEpisodeLink { get }
    var contentType: String { get }
    var headers: [String: String] { get }
    var isAggregated: Bool { get }
    var name: String { get }
    
    init?(playbackURL: String?, parent: NACoreEngineExportsEpisode?, contentType: String?, headers: [String: String]?, isAggregated: NSNumber?)
}

@available(iOS 13, *)
@objc class NACoreEngineExportsPlaybackMedia: NSObject, NACoreEngineExportsPlaybackMediaProtocol {
    var url: String {
        underlyingPlaybackMedia.url.absoluteString
    }
    
    var parent: NACoreEngineExportsEpisode {
        .init(underlyingPlaybackMedia.parent)
    }
    
    var link: NACoreEngineExportsEpisodeLink {
        .init(underlyingPlaybackMedia.link)
    }
    
    var contentType: String {
        underlyingPlaybackMedia.contentType
    }
    
    var headers: [String: String] {
        underlyingPlaybackMedia.headers
    }
    
    var isAggregated: Bool {
        underlyingPlaybackMedia.isAggregated
    }
    
    var name: String {
        underlyingPlaybackMedia.name
    }
    
    var underlyingPlaybackMedia: BasicPlaybackMedia
    
    required init?(playbackURL playbackURLString: String?, parent: NACoreEngineExportsEpisode?, contentType: String?, headers: [String: String]?, isAggregated: NSNumber?) {
        guard let engine = NACoreEngine.current() else {
            Log.error("[NACoreEngineExportsPlaybackMedia] Init must be called from a JavaScript context.")
            return nil
        }
        
        guard let parentEpisode = parent else {
            engine.raiseErrorInContext(NineAnimatorError.argumentError("Parent episode object is either undefined or invalid."))
            return nil
        }
        
        guard let playbackURLString = playbackURLString, let playbackURL = URL(
                protocolRelativeString: playbackURLString,
                relativeTo: parentEpisode.underlyingEpisodeObject.parentLink.link
        ) else {
            engine.raiseErrorInContext(NineAnimatorError.argumentError("Playback URL is either undefined or invalid."))
            return nil
        }
        
        guard let contentType = contentType else {
            engine.raiseErrorInContext(NineAnimatorError.argumentError("ContentType is either undefined or invalid."))
            return nil
        }
        
        self.underlyingPlaybackMedia = .init(
            url: playbackURL,
            parent: parentEpisode.underlyingEpisodeObject,
            contentType: contentType,
            headers: engine.validateValue(headers) ?? [:],
            isAggregated: isAggregated?.boolValue ?? DummyParser.isAggregatedAsset(mimeType: contentType)
        )
        
        super.init()
    }
    
    init(_ nativeBasicMedia: BasicPlaybackMedia) {
        self.underlyingPlaybackMedia = nativeBasicMedia
        super.init()
    }
}
