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

class EasyLoadParser: VideoProviderParser {
    var aliases: [String] { [] }
    
    private static let exdataRegex = try! NSRegularExpression(
        pattern: "data=\"([^\"]+)",
        options: []
    )
    
    struct Response: Codable {
        var streams: [String: Stream]
    }

    struct Stream: Codable {
        var src: String
        var type: String
    }
    
    func parse(episode: Episode, with session: Session, forPurpose purpose: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let additionalResourceRequestHeaders: HTTPHeaders = [
            "Referer": episode.parent.link.link.absoluteString
        ]
        
        return session.request(
                episode.target,
                headers: additionalResourceRequestHeaders
            ).responseString {
            response in
            do {
                let responseContent: String
                switch response.result {
                case let .success(c): responseContent = c
                case let .failure(error): throw error
                }
                
                let source = try (EasyLoadParser
                    .exdataRegex
                    .firstMatch(in: responseContent)?
                    .firstMatchingGroup).tryUnwrap(.providerError("Unable to find the streaming resource"))
                
                let result = try self.decodeBase64(base64EncodedString: source).data(using: .utf8)!
                
                let decodedResponse = try JSONDecoder().decode(
                    Response.self,
                    from: result
                )
                
                let streamEncoded = try decodedResponse
                    .streams
                    .first
                    .tryUnwrap()
                    .value
                    .src
                    .data(using: .init(rawValue: 0))
                    .tryUnwrap(.providerError("No available source was found"))
                
                let key = try "15".data(using: .utf8).tryUnwrap()
                let decryptResult = try self.xorCrypt(streamEncoded, key: key).tryUnwrap(.providerError("Failed XOR"))
                
                let sourceUrl = try String(data: decryptResult, encoding: .utf8).tryUnwrap(.providerError("Malformed data"))
                let resourceUrl = try URL(string: sourceUrl).tryUnwrap(.urlError)
                
                Log.info("(EasyLoad Parser) found asset at %@", resourceUrl.absoluteString)
                
                handler(BasicPlaybackMedia(
                    url: resourceUrl,
                    parent: episode,
                    contentType: "application/vnd.apple.mpegurl",
                    headers: [:],
                    isAggregated: true), nil)
            } catch { handler(nil, error) }
        }
    }
    
    func xorCrypt(_ data: Data, key: Data) -> Data? {
        guard !key.isEmpty else { return nil }
        return Data(data.enumerated().map {
            $0.element ^ key[$0.offset % key.count]
        })
    }
    
    func decodeBase64(base64EncodedString: String) throws -> String {
        let data = try Data(base64Encoded: base64EncodedString).tryUnwrap(
            .responseError("Invalid base64 parameter")
        )
        
        let stringData = try String(data: data, encoding: .utf8).tryUnwrap(.responseError("Malformed data"))
        
        guard Data(base64Encoded: stringData) == nil else {
            return try decodeBase64(base64EncodedString: stringData)
        }
        
        return stringData
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
