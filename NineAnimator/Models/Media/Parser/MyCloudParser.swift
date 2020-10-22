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
import AVKit
import Foundation

class MyCloudParser: VideoProviderParser {
    var aliases: [String] {
        [ "MyCloud" ]
    }
    
    static let videoIdentifierRegex = try! NSRegularExpression(
        pattern: "videoId:\\s*'([^']+)",
        options: .caseInsensitive
    )
    static let videoSourceRegex = try! NSRegularExpression(
        pattern: "\"file\":\"([^\"]+)",
        options: .caseInsensitive
    )
    static let windowKeyRegex = try! NSRegularExpression(
        pattern: "'([^']+)",
        options: .caseInsensitive
    )
    static let windowKeyRetrivalEndpoint = URL(string: "https://mcloud2.to/key")!
    static let streamInfoEndpoint = URL(string: "https://mcloud.to/info")!
    
    class func retrieveWindowKey(with session: Session, referer: URL) -> NineAnimatorPromise<String> {
        AsyncRequestHelper(
            session.request(
                MyCloudParser.windowKeyRetrivalEndpoint,
                headers: [ "Referer": referer.absoluteString ]
            )
        ) .stringResponse().then {
            MyCloudParser.windowKeyRegex.firstMatch(in: $0)?.firstMatchingGroup
        }
    }
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise<URL>.firstly {
            let embedUrl = episode.target
            let embedContentId = embedUrl.lastPathComponent
            
            var embedContentInfoUrl = try URLComponents(
                url: MyCloudParser
                    .streamInfoEndpoint
                    .appendingPathComponent(embedContentId),
                resolvingAgainstBaseURL: true
            ).tryUnwrap()
            embedContentInfoUrl.query = embedUrl.query
            embedContentInfoUrl.fragment = embedUrl.fragment
            
            return embedContentInfoUrl.url
        } .thenPromise {
            embedInfoUrl in AsyncRequestHelper(
                session.request(
                    embedInfoUrl,
                    headers: [
                        "Referer": episode.referer,
                        "Accept": "application/json, text/javascript, */*; q=0.01",
                        "User-Agent": self.defaultUserAgent
                    ]
                )
            ) .decodableResponse(ContentInfoResponse.self)
        } .then {
            decodedValue in
            let playlistUrlString = try decodedValue.media.sources.first.tryUnwrap(
                .providerError("No playlist is available")
            ) .file
              .trimmingCharacters(in: .whitespacesAndNewlines)
            let playlistUrl = try URL(string: playlistUrlString).tryUnwrap()
            let playerAdditionalHeaders: HTTPHeaders = [
                "Referer": episode.target.absoluteString,
                "User-Agent": self.defaultUserAgent
            ]
            
            let isHLS = playlistUrl.pathExtension == "m3u8"
            
            return BasicPlaybackMedia(
                url: playlistUrl,
                parent: episode,
                contentType: isHLS ? "application/vnd.apple.mpegurl" : "video/mp4",
                headers: playerAdditionalHeaders.dictionary,
                isAggregated: isHLS
            )
        } .handle(handler)
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        // MyCloud may not work for GoogleCast
        return purpose != .googleCast
    }
}

private extension MyCloudParser {
    struct ContentInfoResponse: Codable {
        var success: Bool
        var media: ContentInfoMediaEntry
    }
    
    struct ContentInfoMediaEntry: Codable {
        var sources: [ContentInfoSource]
    }
    
    struct ContentInfoSource: Codable {
        var file: String
    }
}
