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
import NineAnimatorCommon

// thanks @ISnackable
class StreamSBParser: VideoProviderParser {
    var aliases: [String] { [] }
    
    private struct StreamSBAPIResponse: Codable {
        let streamData: StreamData
        let statusCode: Int
    }
    
    private struct StreamData: Codable {
        let file: String?
        let subs: [String?]
        let backup: String
    }
    
    private struct StreamPath: Codable {
        let stream: String
    }
    
    private let pathUrl = URL(string: "https://raw.githubusercontent.com/Cyborg714/sb/main/sb.json")!
    
    private static func randomString(length: Int) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise {
            callback in session.request(self.pathUrl).responseData {
                callback($0.value, $0.error)
            }
        } .then {
            try JSONDecoder().decode(StreamPath.self, from: $0)
        }
        .thenPromise {
            alias -> NineAnimatorPromise<PlaybackMedia> in
            let videoID = episode.target.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "embed-", with: "")
            
            let sourcePath = "\(StreamSBParser.randomString(length: 12))||\(videoID)||\(StreamSBParser.randomString(length: 12))||streamsb"
            
            let hexPath = Data(sourcePath.utf8).map {
                String(format: "%x", $0 )
            }.joined()
            
            let streamUrl = try episode.target.host.tryUnwrap()
            let sourceURLString = "https://\(streamUrl)/\(alias.stream)/\(hexPath)"
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            return NineAnimatorPromise {
                callback in session.request(
                    sourceURLString,
                    headers: [
                        "watchsb": "sbstream",
                        "referer": episode.target.absoluteString,
                        "user-agent": self.defaultUserAgent
                    ]
                ) .responseData {
                    callback($0.value, $0.error)
                }
            } .then {
                try decoder.decode(StreamSBAPIResponse.self, from: $0)
            } .then {
                decoded in
                
                let streamData = decoded.streamData
                
                let resourceUrl = try URL(string: streamData.file ?? streamData.backup).tryUnwrap(.urlError)
                
                Log.info("(StreamSB Parser) found asset at %@", resourceUrl.absoluteString)
                
                return BasicPlaybackMedia(
                    url: resourceUrl,
                    parent: episode,
                    contentType: "application/vnd.apple.mpegurl",
                    headers: [
                        "user-agent": self.defaultUserAgent
                    ],
                    isAggregated: true
                )
            }
        }.handle(handler)
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
