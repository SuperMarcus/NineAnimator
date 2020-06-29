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

class HydraXParser: VideoProviderParser {
    var aliases: [String] {
        [ "HydraX", "replay.watch", "Server Hyrax" ]
    }
    
    private static let vipChannelResourceRequestUrl = URL(string: "https://multi.idocdn.com/vip")!
    private static let guestChannelResourceRequestUrl = URL(string: "https://ping.idocdn.com/")!
    
    private static let resourceInfoRegex = try! NSRegularExpression(
        pattern: "options\\s+=\\s+(\\{[^}]+\\})",
        options: []
    )
    
    private struct ResourceOptions: Codable {
        var key: String
        var type: String
        var value: String
//        var aspectratio: String
    }
    
    private struct ResourceResponseSources: Codable {
        var file: String
        var type: String
    }
    
    private struct ResourceResponse: Codable {
        var status: Bool
        var sources: ResourceResponseSources?
    }
    
    private struct ResourceAuthenticatingResponse: Codable {
        var status: Bool
        var url: String
        var sources: [String]?
    }
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        if episode.target.host?.lowercased() == "replay.watch" {
            return parseReplay(episode: episode, with: session, onCompletion: handler)
        } else {
            return parseGeneric(episode: episode, with: session, onCompletion: handler)
        }
    }
    
    private func parseGeneric(episode: Episode, with session: Session, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise.firstly {
            () -> String? in
            let queryParameters = try formDecode(episode.target.query ?? "")
            let fragmentParameters = try formDecode(episode.target.fragment ?? "")
            let parameters = queryParameters.merging(fragmentParameters) { $1 }
            return parameters["slug"] ?? parameters["v"]
        } .thenPromise {
            slug in NineAnimatorPromise<(Data, String)> {
                callback in session.request(
                    HydraXParser.guestChannelResourceRequestUrl,
                    method: .post,
                    parameters: [
                        "slug": slug
                    ],
                    encoding: URLEncoding.default,
                    headers: nil
                ) .responseData {
                    if let responseValue = $0.value {
                        callback((responseValue, slug), nil)
                    } else {
                        callback(nil, $0.error)
                    }
                }
            }
        } .thenPromise {
            try self.decodePlaybackMedia(
                withResponseData: $0,
                slug: $1,
                session: session,
                episode: episode
            )
        } .handle(handler)
    }
    
    /// Replay.watch uses HydraX's vip channel
    private func parseReplay(episode: Episode, with session: Session, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise<String> {
            callback in session.request(episode.target).responseString {
                callback($0.value, $0.error)
            }
        } .thenPromise {
            responseContent -> NineAnimatorPromise<Data> in
            let hydraxSlug = try formDecode(
                try episode.target.fragment.tryUnwrap(.responseError("HydraX resource must contain a fragment"))
            ) .value(at: "slug", type: String.self)
            let resourceOptionsData = try HydraXParser
                .resourceInfoRegex
                .firstMatch(in: responseContent)
                .tryUnwrap(.responseError("Unable to find information identifying the playback resource"))
                .firstMatchingGroup!
                .replacingOccurrences(of: "([a-zA-Z0-9_-]+):([^,\\n\\r]+,*)", with: "\"$1\":$2", options: [.regularExpression])
                .replacingOccurrences(of: "HYDRAX_SLUG", with: "\"\(hydraxSlug)\"")
                .data(using: .utf8)
                .tryUnwrap()
            let resourceOptions = try JSONDecoder().decode(
                ResourceOptions.self,
                from: resourceOptionsData
            )
            
            return NineAnimatorPromise {
                callback in session.request(
                    HydraXParser.vipChannelResourceRequestUrl,
                    method: .post,
                    parameters: [
                        "key": resourceOptions.key,
                        "type": resourceOptions.type,
                        "value": resourceOptions.value,
                        "dataType": "m3u8"
                    ],
                    encoding: URLEncoding.default,
                    headers: nil
                ) .responseData { callback($0.value, $0.error) }
            }
        } .thenPromise {
            try self.decodePlaybackMedia(
                withResponseData: $0,
                slug: "",
                session: session,
                episode: episode
            )
        } .handle(handler)
    }
    
    /// Decode the generic resource response data into a valid `BasicPlaybackMedia`
    private func decodePlaybackMedia(withResponseData resourceResponseData: Data, slug: String, session: Session, episode: Episode) throws -> NineAnimatorPromise<PlaybackMedia> {
        if let decodedResource = try? JSONDecoder().decode(
                ResourceResponse.self,
                from: resourceResponseData
            ) {
            // Decode legacy version
            return .success(try decodeLegacyPlaybackMedia(
                resource: decodedResource,
                episode: episode
            ))
        }
        
        if let decodedResource = try? JSONDecoder().decode(
                ResourceAuthenticatingResponse.self,
                from: resourceResponseData
            ) {
            return try decodeAuthenticatingPlaybackMedia(
                resource: decodedResource,
                slug: slug,
                session: session,
                episode: episode
            )
        }
        
        return .fail(.providerError("NineAnimator doesn't have a decoding strategy for the current resource"))
    }
    
    private func decodeAuthenticatingPlaybackMedia(resource: ResourceAuthenticatingResponse, slug: String, session: Session, episode: Episode) throws -> NineAnimatorPromise<PlaybackMedia> {
        // Original Message: We're processing this video. Please check back later
        guard let assetVariants = resource.sources else {
            return .fail(.providerError("The streaming server is currently processing this content"))
        }
        
        let authenticationUrl = try URL(string: "https://img.iamcdn.net/\(slug).jpg")
            .tryUnwrap()
        let additionalHeaders: HTTPHeaders = [
            "Referer": episode.target.absoluteString
        ]
        var authenticationRequest = try URLRequest(
            url: authenticationUrl,
            method: .get,
            headers: additionalHeaders
        )
        authenticationRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let generateTs = { Int(Date().timeIntervalSince1970 * 1000) }
        let resourceDefMappers: [String: () -> URL?] = [
            "fullHd": {
                URL(string: "https://whw\(slug).\(resource.url)#ht=\(generateTs())")
            },
            "hd": {
                URL(string: "https://www\(slug).\(resource.url)#st=\(generateTs())")
            },
            "sd": {
                URL(string: "https://\(slug).\(resource.url)#ht=\(generateTs())")
            }
        ]
        
        return NineAnimatorPromise {
            callback in session.request(
                authenticationRequest
            ) .responseData {
                callback($0.value, $0.error)
            }
        } .then {
            _ in
            // Select the highest resolution possible
            let preferredSource = assetVariants.contains("fullHd")
                ? "fullHd" : assetVariants.contains("hd")
                ? "hd" : assetVariants.last ?? ""
            let signedResourceUrl = try (resourceDefMappers[preferredSource]?())
                .tryUnwrap(.providerError("Unable to find the desired resource"))
            
            Log.info(
                "[Parser.HydraX] Found legacy asset at %@",
                signedResourceUrl.absoluteString
            )
            
            return BasicPlaybackMedia(
                url: signedResourceUrl,
                parent: episode,
                contentType: "video/mp4",
                headers: [:],
                isAggregated: false
            )
        }
    }
    
    /// Decode the legacy sources with playback URLs included in the `sources` object
    private func decodeLegacyPlaybackMedia(resource: ResourceResponse, episode: Episode) throws -> PlaybackMedia {
        let sources = try resource.sources.tryUnwrap(
            .providerError("Unable to fetch the resourcee")
        )
        let target = try URL(
            string: sources.file
        ).tryUnwrap()
        let isAggregated = sources.type.caseInsensitiveCompare("mp4") != .orderedSame
        Log.info("[Parser.HydraX] Found legacy asset at %@", target.absoluteString)
        
        return BasicPlaybackMedia(
            url: target,
            parent: episode,
            contentType: isAggregated ? "application/vnd.apple.mpegurl" : "video/mp4",
            headers: [:],
            isAggregated: isAggregated
        )
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        // Download is not supported, since HydraX uses AES-128 encryption,
        // `AVAssetDownloadURLSession` does not cache encryption keys
        return purpose != .download
    }
}
