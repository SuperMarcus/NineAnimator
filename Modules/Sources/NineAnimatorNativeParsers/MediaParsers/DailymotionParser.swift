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

class DailymotionParser: VideoProviderParser {
    var aliases: [String] {
        [ "Dailymotion", "Daily motion" ]
    }

    private static let baseSourceURL = URL(string: "https://www.dailymotion.com/")!
    private static let graphqlApiBase = URL(string: "https://graphql.api.dailymotion.com/")!
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        if episode.userInfo["password"] != nil {
            return parsePassword(episode: episode, with: session, onCompletion: handler)
        } else {
            return parseGeneric(episode: episode, with: session, onCompletion: handler)
        }
    }
    
    private func parseGeneric(episode: Episode, with session: Session, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise {
            callback in session.request(
                DailymotionParser.baseSourceURL.appendingPathComponent("player/metadata/video/\(episode.target.lastPathComponent)")
            ) .responseDecodable(of: MetadataResponse.self, decoder: self.decoder) {
                callback($0.value, $0.error)
            }
        } .then {
            metadataResponse in
            
            let resourceUrl = try URL(string: metadataResponse.qualities.auto.first?.url ?? "").tryUnwrap(.urlError)
            let isHLSAsset = (metadataResponse.qualities.auto.first?.type.contains("mpegURL") ?? false)

            Log.info("(Dailymotion Parser) found asset at %@", resourceUrl.absoluteString)

            return BasicPlaybackMedia(
                url: resourceUrl,
                parent: episode,
                contentType: isHLSAsset ? "application/vnd.apple.mpegurl" : "video/mp4",
                headers: [ "referer": episode.target.absoluteString ],
                isAggregated: isHLSAsset
            )
        } .handle(handler)
    }
    
    private func parsePassword(episode: Episode, with session: Session, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise {
            callback in session.request(
                DailymotionParser.graphqlApiBase.appendingPathComponent("oauth/token"),
                method: .post,
                parameters: [
                    "client_id": "f1a362d288c1b98099c7",
                    "client_secret": "eea605b96e01c796ff369935357eca920c5da4c5",
                    "grant_type": "client_credentials"
                ],
                headers: [
                    "referer": DailymotionParser.baseSourceURL.absoluteString
                ]
            ) .responseDecodable(of: TokenResponse.self, decoder: self.decoder) {
                callback($0.value, $0.error)
            }
        } .thenPromise {
            tokenResponse -> NineAnimatorPromise<PlaybackMedia> in
            
            let videoId = episode.target.lastPathComponent
            let password = episode.userInfo["password"]
            
            let clientToken = tokenResponse.accessToken
            let body: [String: Any] = [
                "query": "query playerPasswordQuery($videoId: String!, $password: String!){video(xid: $videoId, password:$password){id xid}}",
                "variables": [
                    "videoId": videoId,
                    "password": password
                ]
            ]
            let headers: HTTPHeaders = [
                .authorization(bearerToken: clientToken),
                .init(name: "Origin", value: DailymotionParser.baseSourceURL.absoluteString),
                .init(name: "User-Agent", value: self.defaultUserAgent)
            ]
            
            return NineAnimatorPromise {
                callback in session.request(
                    DailymotionParser.graphqlApiBase,
                    method: .post,
                    parameters: body,
                    encoding: JSONEncoding.default,
                    headers: headers
                ).responseDecodable(of: PasswordResponse.self, decoder: self.decoder) {
                    callback($0.value, $0.error)
                }
            } .thenPromise {
                passwordResponse -> NineAnimatorPromise<PlaybackMedia> in
                                
                let xid = passwordResponse.data.video.xid
                
                return NineAnimatorPromise {
                    callback in session.request(
                        DailymotionParser.baseSourceURL.appendingPathComponent("player/metadata/video/\(xid)")
                    ) .responseDecodable(of: MetadataResponse.self, decoder: self.decoder) {
                        callback($0.value, $0.error)
                    }
                } .then {
                    metadataResponse -> PlaybackMedia in

                    let resourceUrl = try URL(string: metadataResponse.qualities.auto.first?.url ?? "").tryUnwrap(.urlError)
                    let isHLSAsset = (metadataResponse.qualities.auto.first?.type.contains("mpegURL") ?? false)
                    
                    Log.info("(Dailymotion Parser) found asset at %@", resourceUrl.absoluteString)

                    return BasicPlaybackMedia(
                        url: resourceUrl,
                        parent: episode,
                        contentType: isHLSAsset ? "application/vnd.apple.mpegurl" : "video/mp4",
                        headers: [ "referer": episode.target.absoluteString ],
                        isAggregated: isHLSAsset
                    )
                }
            }
        } .handle(handler)
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}

// MARK: - Request-Related Structs
extension DailymotionParser {
    private struct TokenResponse: Decodable {
        let accessToken: String
        let expiresIn: Int
        let scope: String
        let tokenType: String
    }
    
    private struct PasswordResponse: Decodable {
        let data: PasswordData
    }
    
    private struct PasswordData: Decodable {
        let video: VideoId
    }
    
    private struct VideoId: Decodable {
        let id: String
        let xid: String
    }
    
    private struct MetadataResponse: Decodable {
        let url: String
        let id, title: String
        let qualities: Qualities
//        let subtitles: Subtitles
    }
    
    private struct Qualities: Decodable {
        let auto: [Auto]
    }
    
    private struct Auto: Decodable {
        let type: String
        let url: String
    }
    
//    private struct Subtitles: Decodable {
//        let enable: Bool
//        let data: [String: DataClass]?
//    }
//
//    struct DataClass: Decodable {
//        let label: String
//        let urls: [String]
//    }
}
