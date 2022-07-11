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
    
    private static let versionRegex = try! NSRegularExpression(
        pattern: #"app.+js[^\"']"#,
        options: .caseInsensitive
    )
    
    private static let part2Regex = try! NSRegularExpression(
        pattern: #"\'(ces\w{2,3})\'"#,
        options: .caseInsensitive
    )
    
    private static let part3Regex = try! NSRegularExpression(
        pattern: #"\'(\d{1,2}\/)\'"#,
        options: .caseInsensitive
    )
    
    private let apiPath: String = "https://watchsb.com/\("SOURCES")/566d337678566f743674494a7c7c\("HEXVIDEOID")7c7c346b6767586d6934774855537c7c73747265616d7362/6565417268755339773461447c7c346133383438333436313335376136323337373433383634376337633465366534393338373136643732373736343735373237613763376334363733353737303533366236333463353333363534366137633763373337343732363536313664373336327c7c6b586c3163614468645a47617c7c73747265616d7362"
    
    private func getAlias(url: URL, with session: Session) -> NineAnimatorPromise<String> {
        NineAnimatorPromise {
            callback in session.request(url).responseString {
                callback($0.value, $0.error)
            }
        } .thenPromise {
            responseContent in
            
            // let versionNo = try (
            //     StreamSBParser.versionRegex.firstMatch(in: responseContent)?.firstMatchingGroup
            // ).tryUnwrap()
            let jsURL = try (
                StreamSBParser.versionRegex.firstMatch(in: responseContent)?[safe: 0]
            ).tryUnwrap()
            
            return NineAnimatorPromise {
                callback in session.request("https://watchsb.com/js/\(jsURL)", headers: [
                    "watchsb": "streamsb",
                    "Referer": url.absoluteString
                ]).responseString {
                    callback($0.value, $0.error)
                }
            } .then {
                resourceInfoRes in
                
                let part1 = "sour"
                let part2 = try (
                    StreamSBParser.part2Regex.firstMatch(in: resourceInfoRes)?.firstMatchingGroup
                ).tryUnwrap()
                
                let part3Match = StreamSBParser.part3Regex.firstMatch(in: resourceInfoRes)
                var part3 = ""
                if let part3Match = part3Match {
                    part3 = try (part3Match.firstMatchingGroup).tryUnwrap()
                }
                let alias = part1 + part2 + part3
                
                return alias
            }
        }
    }
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        // thanks @awsomedude
        self.getAlias(url: episode.target, with: session)
            .thenPromise {
                alias -> NineAnimatorPromise<PlaybackMedia> in
                let videoID = episode.target.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "embed-", with: "")
                
                let hexVideoID = Data(videoID.utf8).map {
                    String(format: "%x", $0 )
                }.joined()
                
                var sourceURLString = self.apiPath.replacingOccurrences(of: "HEXVIDEOID", with: hexVideoID)
                sourceURLString = sourceURLString.replacingOccurrences(of: "SOURCES", with: alias)
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                return NineAnimatorPromise {
                    callback in session.request(
                        sourceURLString,
                        headers: [
                            "watchsb": "streamsb",
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
