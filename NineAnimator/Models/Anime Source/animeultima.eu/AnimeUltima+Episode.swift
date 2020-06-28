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
import SwiftSoup

extension NASourceAnimeUltima {
    /// The available information found on the episode page
    struct EpisodePageInformation {
        typealias MirrorIdentifier = URL
        
        /// The available mirrors
        ///
        /// Stores the name of the mirror corresponding to the MirrorIdentifier
        var availableMirrors: [MirrorIdentifier: String]
        
        /// The mirror selected under the current page
        var currentMirror: MirrorIdentifier
        
        /// The target url of the current mirror
        var frameUrl: URL
    }
    
    /// Request the information listed on the specified episode page
    func pageInformation(for episodeUrl: URL) -> NineAnimatorPromise<EpisodePageInformation> {
        requestManager
            .request(url: episodeUrl, handling: .browsing)
            .responseString
            .then {
                responseContent in
                let bowl = try SwiftSoup.parse(responseContent)
                
                // Find the mirrors in the mirror-selector element
                let mirrorsContainer = try bowl.select(".is-hidden-touch select.mirror-selector")
                var mirrorList = [EpisodePageInformation.MirrorIdentifier: String]()
                var selectedMirrorIdentifier: EpisodePageInformation.MirrorIdentifier?
                
                // Iterate through the option menu
                for mirror in try mirrorsContainer.select("option") {
                    guard let mirrorIdentifier: EpisodePageInformation.MirrorIdentifier =
                        URL(string: try mirror.attr("value")) else {
                        continue
                    }
                    
                    let mirrorName = try mirror
                        .text()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
//                        .replacingOccurrences(
//                            of: "^[^:]+:\\s+",
//                            with: "", // Trim away the "Subbed: " or "Dubbed: " prefixes
//                            options: [.regularExpression]
//                        )
                    
                    // If this mirror has the 'selected' attribute, store it as the current mirror
                    if mirror.hasAttr("selected") {
                        selectedMirrorIdentifier = mirrorIdentifier
                    }
                    
                    // Store the mirror name and identifier
                    mirrorList[mirrorIdentifier] = mirrorName
                }
                
                // Obtain the mirror's streaming frame url
                guard let frameUrl = URL(string: try bowl.select("iframe").attr("src"), relativeTo: episodeUrl) else {
                    throw NineAnimatorError.urlError
                }
                
                // If the list of mirror is empty, determine the name of the current server
                // and add the current address to the mirror list
                if mirrorList.isEmpty {
                    let nameOfMirror: String
                    switch frameUrl {
                    case _ where try bowl.select("iframe").attr("src").hasPrefix("/e"):
                        nameOfMirror = "AUEngine"
                    case _ where frameUrl.host?.hasPrefix("faststream") == true:
                        nameOfMirror = "FastStream"
                    case _ where frameUrl.host == "animeultima.ch":
                        nameOfMirror = "AU.ch"
                    case _ where frameUrl.host?.hasSuffix("rapidvideo.com") == true:
                        nameOfMirror = "Rapid Video"
                    case _ where frameUrl.host?.hasSuffix("streamango.com") == true:
                        nameOfMirror = "Streamango"
                    case _ where frameUrl.host?.hasSuffix("mp4upload.com") == true:
                        nameOfMirror = "Mp4Upload"
                    case _ where frameUrl.host?.hasSuffix("animefever.tv") == true:
                        nameOfMirror = "AF"
                    default: nameOfMirror = frameUrl.host!
                    }
                    mirrorList[episodeUrl] = nameOfMirror
                    selectedMirrorIdentifier = episodeUrl
                }
                
                guard let currentMirrorIdentifier = selectedMirrorIdentifier ?? mirrorList.first?.key else {
                    throw NineAnimatorError.responseError("No available episode found for this anime")
                }
                
                // Construct the page information struct
                return EpisodePageInformation(
                    availableMirrors: mirrorList,
                    currentMirror: currentMirrorIdentifier,
                    frameUrl: frameUrl
                )
            }
    }
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        pageInformation(for: anime.link.link.appendingPathComponent(link.identifier))
            .thenPromise {
                initialEpisodePage -> NineAnimatorPromise<EpisodePageInformation> in
                // Obtain the url for the selected page
                let realEpisodePageUrl = try some(
                    initialEpisodePage
                        .availableMirrors
                        .first { $0.value == link.server }?
                        .key,
                    or: .responseError("This episode is not available on the selected server")
                )
                
                // Avoid repeated requests if possible
                if initialEpisodePage.currentMirror == realEpisodePageUrl {
                    return .success(initialEpisodePage)
                } else { return self.pageInformation(for: realEpisodePageUrl) }
            } .then {
                episodePage in Episode(
                    link,
                    target: episodePage.frameUrl,
                    parent: anime,
                    referer: episodePage.currentMirror.absoluteString,
                    userInfo: [ "page": episodePage ]
                )
            }
    }
}
