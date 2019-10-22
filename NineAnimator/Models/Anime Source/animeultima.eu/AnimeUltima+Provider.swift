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

import Alamofire
import Foundation

extension NASourceAnimeUltima {
    /// A private parser for animeultima's AUEngine server
    class AUEngineParser: VideoProviderParser {
        var aliases: [String] { return [ "AUEngine" ] }
        
        private var source: NASourceAnimeUltima
        
        init(_ source: NASourceAnimeUltima) {
            self.source = source
        }
        
        func parse(episode: Episode,
                   with session: SessionManager,
                   onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
            return source
                .request(browseUrl: episode.target)
                .then {
                    responseContent in
                    let resourceMatchingRegex = try NSRegularExpression(
                        pattern: "file:\\s+\"([^\"]+)",
                        options: []
                    )
                    
                    // Match the first file url
                    guard let resourceUrlString = resourceMatchingRegex
                        .firstMatch(in: responseContent)?
                        .firstMatchingGroup else {
                        throw NineAnimatorError.providerError("Cannot find a streambale resource in the selected page")
                    }
                    
                    guard let resourceUrl = URL(string: resourceUrlString) else {
                        throw NineAnimatorError.urlError
                    }
                    
                    Log.info("(AnimeUltima.AUEngine Parser) Found asset at %@", resourceUrlString)
                    
                    let aggregated = resourceUrl.pathExtension.lowercased() == "m3u8"
                    
                    // Construct playback media
                    return BasicPlaybackMedia(
                        url: resourceUrl,
                        parent: episode,
                        contentType: aggregated ? "application/vnd.apple.mpegurl" : "video/mp4",
                        headers: [:],
                        isAggregated: aggregated
                    )
                } .handle(handler)
        }
    }
    
    /// A private parser for animeultima's FastStream server
    class FastStreamParser: VideoProviderParser {
        var aliases: [String] {
            return [ "FastStream", "FastStream 2" ]
        }
        
        private var source: NASourceAnimeUltima
        
        init(_ source: NASourceAnimeUltima) {
            self.source = source
        }
        
        func parse(episode: Episode,
                   with session: SessionManager,
                   onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
            return source
                .request(browseUrl: episode.target)
                .then {
                    responseContent in
                    let resourceMatchingRegex = try NSRegularExpression(
                        pattern: "file:\\s+\"([^\"]+)",
                        options: []
                    )
                    
                    // Match the first file url
                    guard let resourceUrlString = resourceMatchingRegex
                        .firstMatch(in: responseContent)?
                        .firstMatchingGroup else {
                            throw NineAnimatorError.providerError("Cannot find a streambale resource in the selected page")
                    }
                    
                    guard let resourceUrl = URL(string: resourceUrlString) else {
                        throw NineAnimatorError.urlError
                    }
                    
                    Log.info("(AnimeUltima.FastStream Parser) Found asset at %@", resourceUrlString)
                    
                    // Construct playback media
                    return BasicPlaybackMedia(
                        url: resourceUrl,
                        parent: episode,
                        contentType: "application/x-mpegURL",
                        headers: [:],
                        isAggregated: true
                    )
                } .handle(handler)
        }
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        let possibleProviderName = server.replacingOccurrences(
            of: "^[^:]+:\\s+",
            with: "", // Trim away the "Subbed: " or "Dubbed: " prefixes
            options: [ .regularExpression ]
        )
        
        // Return private provider parsers
        switch server {
        case let server where server.hasSuffix("AUEngine"): return _auEngineParser
        case let server where server.contains("FastStream"): return _fastStreamParser
        default: break
        }
        
        return VideoProviderRegistry.default.provider(for: possibleProviderName)
    }
}
