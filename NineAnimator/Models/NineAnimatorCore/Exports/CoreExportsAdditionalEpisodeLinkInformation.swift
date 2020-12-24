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
@objc protocol NACoreEngineExportsAdditionalEpisodeLinkInformationProtocol: JSExport {
    var parent: NACoreEngineExportsEpisodeLink { get }
    var synopsis: String? { get set }
    var airDate: String? { get set }
    var season: String? { get set }
    var episodeNumber: NSNumber? { get set }
    var title: String? { get set }
    
    init?(parentEpisodeLink: NACoreEngineExportsEpisodeLink?)
}

@available(iOS 13, *)
@objc class NACoreEngineExportsAdditionalEpisodeLinkInformation: NSObject, NACoreEngineExportsAdditionalEpisodeLinkInformationProtocol {
    dynamic var synopsis: String?
    dynamic var airDate: String?
    dynamic var season: String?
    dynamic var episodeNumber: NSNumber?
    dynamic var title: String?
    
    dynamic var parent: NACoreEngineExportsEpisodeLink {
        .init(parentLink)
    }
    
    let parentLink: EpisodeLink
    
    var nativeAdditionalEpisodeLinkInformation: Anime.AdditionalEpisodeLinkInformation {
        .init(
            parent: parentLink,
            synopsis: synopsis,
            airDate: airDate,
            season: season,
            episodeNumber: episodeNumber?.intValue,
            title: title
        )
    }
    
    required init?(parentEpisodeLink: NACoreEngineExportsEpisodeLink?) {
        if let parentLink = parentEpisodeLink?.nativeEpisodeLink {
            self.parentLink = parentLink
        } else {
            // Raise error in the current context
            if let currentEngine = NACoreEngine.current() {
                currentEngine.raiseErrorInContext(NineAnimatorError.argumentError("Parent EpisodeLink must be well defined and valid"))
            }
            return nil
        }
        
        super.init()
    }
    
    init(_ nativeEpisodeInfo: Anime.AdditionalEpisodeLinkInformation) {
        self.parentLink = nativeEpisodeInfo.parent
        self.synopsis = nativeEpisodeInfo.synopsis
        self.airDate = nativeEpisodeInfo.airDate
        self.season = nativeEpisodeInfo.season
        self.title = nativeEpisodeInfo.title
        
        if let providedEpisodeNumber = nativeEpisodeInfo.episodeNumber {
            self.episodeNumber = .init(value: providedEpisodeNumber)
        }
    }
}
