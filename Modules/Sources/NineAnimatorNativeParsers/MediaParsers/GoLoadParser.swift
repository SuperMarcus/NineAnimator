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

class GoLoadParser: VideoProviderParser {
    var aliases: [String] {
        [ "GoLoad.Pro", "Gogo Server" ]
    }
    
    private static let tokenKey = Data(base64Encoded: "OTMxMDYxNjU3MzQ2NDA0NTk3MjgzNDY1ODkxMDY3OTE=")!
    private static let resourceKey = Data(base64Encoded: "OTc5NTIxNjA0OTM3MTQ4NTIwOTQ1NjQ3MTIxMTgzNDk=")!
    private static let sharedIv = Data(base64Encoded: "ODI0NDAwMjQ0MDA4OTE1Nw==")!
    private static let resourceRequestUrl = URL(string: "https://goload.pro/encrypt-ajax.php")!
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise<URL>.firstly {
            try Self.buildSignedResourceUrl(embedUrl: episode.target)
        } .thenPromise {
            signedResourceUrl in NineAnimatorPromise {
                cb in session.request(signedResourceUrl, headers: [
                    "X-Requested-With": "XMLHttpRequest"
                ]).responseDecodable(of: EncryptedResourceResponse.self) {
                    cb($0.value, $0.error)
                }
            }
        } .then {
            encryptedDataResponse in try Self.decryptGoLoad(
                data: encryptedDataResponse.data,
                key: Self.resourceKey
            )
        } .then {
            decryptedData in
            try JSONDecoder().decode(ResourceInfoResponse.self, from: decryptedData)
        } .then {
            decryptedAssetList in
            let firstAvailableSource = try decryptedAssetList
                .source
                .first
                .tryUnwrap(.providerError("No source is available at this time"))
            let isHLSAsset = firstAvailableSource.type.caseInsensitiveCompare("mp4") != .orderedSame
            
            Log.info("(GoLoad.Pro Parser) found asset at %@", firstAvailableSource.file.absoluteString)
            
            return BasicPlaybackMedia(
                url: firstAvailableSource.file,
                parent: episode,
                contentType: isHLSAsset ? "application/vnd.apple.mpegurl" : "video/mp4",
                headers: [ "Referer": episode.target.absoluteString ],
                isAggregated: isHLSAsset
            )
        } .handle(handler)
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}

// MARK: - Crypto Helpers
private extension GoLoadParser {
    static func decryptGoLoad(data: Data, key: Data) throws -> Data {
        let decryptDataSize = data.count + kCCBlockSizeAES128
        var decryptedData = Data(count: decryptDataSize)
        var decryptedBytes = 0
        
        let decryptionResult = decryptedData.withUnsafeMutableBytes {
            decryptedDataPtr in key.withUnsafeBytes {
                keyPtr in Self.sharedIv.withUnsafeBytes {
                    ivPtr in data.withUnsafeBytes {
                        cipherPtr in CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress!,
                            key.count,
                            ivPtr.baseAddress!,
                            cipherPtr.baseAddress!,
                            data.count,
                            decryptedDataPtr.baseAddress!,
                            decryptDataSize,
                            &decryptedBytes
                        )
                    }
                }
            }
        }
        
        guard decryptionResult == CCCryptorStatus(kCCSuccess) else {
            throw NineAnimatorError.providerError("Unable to decode resource")
        }
        
        return decryptedData[0..<decryptedBytes]
    }

    static func encryptResourceId(identifier: String) throws -> String {
        let plaintextIdData = try identifier.data(using: .utf8).tryUnwrap()
        
        let encryptedIdBufLen = plaintextIdData.count + kCCBlockSizeAES128
        var encryptedIdData = Data(count: encryptedIdBufLen)
        var encryptedBytes = 0
        
        let encryptResult = encryptedIdData.withUnsafeMutableBytes {
            destDataPtr in Self.tokenKey.withUnsafeBytes {
                keyDataPtr in Self.sharedIv.withUnsafeBytes {
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
        
        return encryptedIdData[0..<encryptedBytes].base64EncodedString()
    }
    
    static func extractUrlResourceValues(embedUrl: URL) throws -> ResourceRequestParameters {
        let embedUrlComponents = try URLComponents(
            url: embedUrl,
            resolvingAgainstBaseURL: true
        ).tryUnwrap()
        let embedUrlResources = (embedUrlComponents.queryItems ?? []).reduce(into: [String: String]()) {
            resDict, item in
            resDict[item.name] = item.value
        }
        return ResourceRequestParameters(
            id: try embedUrlResources["id"].tryUnwrap(),
            token: try embedUrlResources["token"].tryUnwrap(),
            expires: try Int(try embedUrlResources["expires"].tryUnwrap()).tryUnwrap()
        )
    }

    static func generateRandomString(ofLength length: Int) -> String {
        (0..<length).map {
            _ in String(Int.random(in: 0...9))
        } .joined()
    }

    static func buildSignedResourceUrl(embedUrl: URL) throws -> URL {
        let resourceValues = try extractUrlResourceValues(embedUrl: embedUrl)
        let challengeResourceId = try encryptResourceId(identifier: resourceValues.id)
        let challengeValue = generateRandomString(ofLength: 32)
        
        // Build resource request URL
        var resourceUrlBuilder = try URLComponents(
            url: Self.resourceRequestUrl,
            resolvingAgainstBaseURL: true
        ).tryUnwrap()
        
        resourceUrlBuilder.queryItems = [
            .init(name: "id", value: challengeResourceId),
            .init(name: "token", value: resourceValues.token),
            .init(name: "expires", value: .init(resourceValues.expires)),
            .init(name: "mip", value: "0.0.0.0"),
            .init(name: "referer", value: embedUrl.absoluteString),
            .init(name: "ch", value: challengeValue),
            .init(name: "op", value: "2"),
            .init(name: "alias", value: resourceValues.id)
        ]
        
        return try resourceUrlBuilder.url.tryUnwrap()
    }
}

// MARK: - Request-Related Structs
extension GoLoadParser {
    struct ResourceRequestParameters {
        var id: String
        var token: String
        var expires: Int
    }
    
    struct ResourceInfoResponse: Codable {
        var source: [ResourceInfoResponseSource]
    }
    
    struct ResourceInfoResponseSource: Codable {
        var file: URL
        var label: String
        var type: String
    }
    
    struct EncryptedResourceResponse: Codable {
        var data: Data
    }
}
