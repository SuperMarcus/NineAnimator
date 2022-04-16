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
import CommonCrypto
import Foundation
import NineAnimatorCommon

class VidStreamingParser: VideoProviderParser {
    var aliases: [String] {
        [ "VidStreaming", "VidCDN" ]
    }
    
    private static let videoSourceRegex = try! NSRegularExpression(
        pattern: "sources:\\[\\{file:\\s*'([^']+)",
        options: []
    )
    
    private static let encryptionKey = Data(base64Encoded: "MjU3NDY1Mzg1OTI5MzgzOTY3NjQ2NjI4Nzk4MzMyODg=")!
    private static let resourceRequestUrl = URL(string: "https://streamani.net/encrypt-ajax.php")!
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise {
            callback in session.request(episode.target).responseString {
                callback($0.value, $0.error)
            }
        } .thenPromise {
            responseContent -> NineAnimatorPromise<PlaybackMedia> in
            // Try to see if the classic match works
            let resourceMatch = Self.videoSourceRegex.firstMatch(in: responseContent)
            
            if let resourceMatch = resourceMatch,
               let resourceUrlString = resourceMatch.firstMatchingGroup,
               let resourceUrl = URL(string: resourceUrlString) {
                let isHLSAsset = !resourceUrl.absoluteString.contains("mime=video/mp4")
                
                Log.info("(VidStreaming Parser) found asset with traditional resource matching (really?) at %@", resourceUrl.absoluteString)
                
                return .success(BasicPlaybackMedia(
                    url: resourceUrl,
                    parent: episode,
                    contentType: isHLSAsset ? "application/vnd.apple.mpegurl" : "video/mp4",
                    headers: [ "Referer": episode.target.absoluteString ],
                    isAggregated: isHLSAsset
                ))
            } else {
                // Try the new encrypted matching
                let targetUrlComponents = try URLComponents(url: episode.target, resolvingAgainstBaseURL: true).tryUnwrap()
                let resourceId = try targetUrlComponents.queryItems.tryUnwrap().first {
                    $0.name.caseInsensitiveCompare("id") == .orderedSame
                } .tryUnwrap(.providerError("Unable to find a resource identifier"))
                  .value
                  .tryUnwrap(.providerError("Invalid resource identifier"))
                let signedResourceRequestUrl = try Self.signedResourceRequestUrl(forResourceId: resourceId)
                
                Log.info("(VidStreaming Parser) attempting to resolve resouce for ID %@", resourceId)
                
                return NineAnimatorPromise {
                    callback in session.request(signedResourceRequestUrl, headers: [
                        "Referer": episode.target.absoluteString,
                        "X-Requested-With": "XMLHttpRequest",
                        "Accept": "application/json, text/javascript, */*; q=0.01"
                    ]).responseData {
                        callback($0.value, $0.error)
                    }
                } .then {
                    try JSONDecoder().decode(ResourceInfoResponse.self, from: $0)
                } .then {
                    resourceInfoRes in
                    let firstAvailableSource = try resourceInfoRes
                        .source
                        .first
                        .tryUnwrap(.providerError("No source is available at this time"))
                    let isHLSAsset = firstAvailableSource.type.caseInsensitiveCompare("mp4") != .orderedSame
                    
                    Log.info("(VidStreaming Parser) found asset at %@", firstAvailableSource.file.absoluteString)
                    
                    return BasicPlaybackMedia(
                        url: firstAvailableSource.file,
                        parent: episode,
                        contentType: isHLSAsset ? "application/vnd.apple.mpegurl" : "video/mp4",
                        headers: [ "Referer": episode.target.absoluteString ],
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

private extension VidStreamingParser {
    static func generateRandomString(ofLength length: Int) -> String {
        (0..<length).map {
            _ in String(Int.random(in: 0...9))
        } .joined()
    }
    
    static func generateIvAndToken() throws -> (iv: Data, timeToken: String) {
        let ivString = generateRandomString(ofLength: 16)
        let tokenPrefix = generateRandomString(ofLength: 2)
        let tokenSuffix = generateRandomString(ofLength: 2)
        
        return (
            iv: try ivString.data(using: .utf8).tryUnwrap(),
            timeToken: tokenPrefix + ivString + tokenSuffix
        )
    }
    
    static func signedResourceRequestUrl(forResourceId id: String) throws -> URL {
        let (ivData, timeToken) = try generateIvAndToken()
        let plaintextIdData = try id.data(using: .utf8).tryUnwrap()
        
        let encryptedIdBufLen = plaintextIdData.count + kCCBlockSizeAES128
        var encryptedIdData = Data(count: encryptedIdBufLen)
        var encryptedBytes = 0
        
        let encryptResult = encryptedIdData.withUnsafeMutableBytes {
            destDataPtr in encryptionKey.withUnsafeBytes {
                keyDataPtr in ivData.withUnsafeBytes {
                    ivDataPtr in plaintextIdData.withUnsafeBytes {
                        plaintextIdPtr in CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyDataPtr.baseAddress!,
                            kCCKeySizeAES256,
                            ivDataPtr.baseAddress!,
                            plaintextIdPtr.baseAddress!,
                            plaintextIdData.count,
                            destDataPtr.baseAddress!,
                            encryptedIdBufLen,
                            &encryptedBytes
                        )
                    }
                }
            }
        }
        
        guard encryptResult == CCCryptorStatus(kCCSuccess) else {
            throw NineAnimatorError.providerError("Unable to encode resource URL")
        }
        
        let encryptedIdString = encryptedIdData[0..<encryptedBytes].base64EncodedString()
        var signedUrlBuilder = try URLComponents(url: resourceRequestUrl, resolvingAgainstBaseURL: true).tryUnwrap()
        
        signedUrlBuilder.queryItems = [
            .init(name: "id", value: encryptedIdString),
            .init(name: "referer", value: "none"),
            .init(name: "time", value: timeToken)
        ]
        
        return try signedUrlBuilder.url.tryUnwrap()
    }
}

extension VidStreamingParser {
    struct ResourceInfoResponse: Codable {
        var source: [ResourceInfoResponseSource]
    }
    
    struct ResourceInfoResponseSource: Codable {
        var file: URL
        var label: String
        var type: String
    }
}
