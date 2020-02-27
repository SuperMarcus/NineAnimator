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

import Alamofire
import Foundation

/// Parser for animeultima's AUEngine server
class AUEngineParser: VideoProviderParser {
    var aliases: [String] {
        [ "AUEngine" ]
    }
    
    private var source: NASourceAnimeUltima
    
    init(_ source: NASourceAnimeUltima) {
        self.source = source
    }
    
    func parse(episode: Episode,
               with session: Session,
               forPurpose _: Purpose,
               onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        source
            .request(browseUrl: episode.target)
            .then {
                responseContent in
                let fone = try NSRegularExpression(
                    pattern: "fone=\"([^\"]+)",
                    options: .caseInsensitive
                )
                let ftwo = try NSRegularExpression(
                    pattern: "ftwo=\"([^\"]+)",
                    options: .caseInsensitive
                )
                let decodedPackerScript = try PackerDecoder().decode(responseContent)
                let resourceUrlString = try (
                    fone.firstMatch(in: decodedPackerScript)?.firstMatchingGroup
                    ?? ftwo.firstMatch(in: decodedPackerScript)?.firstMatchingGroup
                ) .tryUnwrap(
                    .providerError("Cannot find a streambale resource in the selected page")
                )
                let sourceURL = try URL(string: resourceUrlString).tryUnwrap()
                let aggregated = sourceURL.pathExtension.lowercased() == "m3u8"
                
                Log.info(
                    "(AnimeUltima.AUEngine Parser) Found asset at %@ (HLS: %@)",
                    sourceURL.absoluteString,
                    aggregated
                )
                
                // Construct playback media
                return BasicPlaybackMedia(
                    url: sourceURL,
                    parent: episode,
                    contentType: aggregated ? "application/vnd.apple.mpegurl" : "video/mp4",
                    headers: [:],
                    isAggregated: aggregated
                )
            } .handle(handler)
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
