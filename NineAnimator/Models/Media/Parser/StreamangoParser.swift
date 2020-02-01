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

class StreamangoParser: VideoProviderParser {
    var aliases: [String] {
        [ "Streamango" ]
    }
    
    static let obscuredVideoSourceRegex = try! NSRegularExpression(pattern: "src:\\s*d\\('([^']+)',\\s*([^)]+)\\)", options: .caseInsensitive)
    
    func parse(episode: Episode, with session: SessionManager, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let additionalHeaders: HTTPHeaders = [
            "Referer": episode.parentLink.link.absoluteString
        ]
        Log.debug("Parsing Streamango with referer '%@'", episode.parentLink.link.absoluteString)
        return session.request(episode.target, headers: additionalHeaders).responseString {
            [weak self] response in
            guard let self = self else { return }
            guard let text = response.value else {
                Log.error(response.error)
                return handler(nil, NineAnimatorError.responseError(
                    "response error: \(response.error?.localizedDescription ?? "Unknown")"
                ))
            }
            
            let matches = StreamangoParser.obscuredVideoSourceRegex.matches(
                in: text, range: text.matchingRange
            )
            
            guard let match = matches.first else {
                return handler(nil, NineAnimatorError.responseError(
                    "no matches for source url"
                ))
            }
            
            let obscuredLink = text[match.range(at: 1)]
            
            guard let obscuredDecodingKey = Int(text[match.range(at: 2)]) else {
                return handler(nil, NineAnimatorError.responseError(
                    "decoding key is not an integer"
                ))
            }
            
            let decodedLink = self.decode(obscured: obscuredLink, with: obscuredDecodingKey)
            
            guard let sourceURL = URL(string:
                decodedLink.hasPrefix("//") ? "https:\(decodedLink)" : decodedLink)
                else { return handler(nil, NineAnimatorError.responseError(
                    "source url not recongized"
                ))
            }
            
            Log.info("(Streamango Parser) found asset at %@", sourceURL.absoluteString)
            
            handler(BasicPlaybackMedia(
                url: sourceURL,
                parent: episode,
                contentType: "video/mp4",
                headers: additionalHeaders,
                isAggregated: false), nil)
        }
    }
    
    func decode(obscured: String, with code: Int) -> String {
        func charCode(_ c: Character) -> Int {
            let k = "=/+9876543210zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA"
            return k.distance(from: k.startIndex, to: k.range(of: String(c))!.lowerBound)
        }
        
        func chr(_ c: Int) -> Character {
            Character(UnicodeScalar(c)!)
        }
        
        var _0x59b81a = ""
        var count = 0
        
        var _0x4a2f3a = 0
        var _0x29d5bf = 0
        var _0x3b6833 = 0
        var _0x426d70 = 0
        var _0x2e4782 = 0
        var _0x2c0540 = 0
        var _0x5a46ef = 0
        
        let sequence = obscured.map { charCode($0) }
        
        for _ in 0..<(obscured.count - 1) {
            while count <= (obscured.count - 1) {
                _0x4a2f3a = sequence[count]
                count += 1
                _0x29d5bf = sequence[count]
                count += 1
                _0x3b6833 = sequence[count]
                count += 1
                _0x426d70 = sequence[count]
                count += 1
                
                _0x2e4782 = ((_0x4a2f3a << 2) | (_0x29d5bf >> 4))
                _0x2c0540 = (((_0x29d5bf & 15) << 4) | (_0x3b6833 >> 2))
                _0x5a46ef = ((_0x3b6833 & 3) << 6) | _0x426d70
                _0x2e4782 = _0x2e4782 ^ code
                
                _0x59b81a = "\(_0x59b81a)\(chr(_0x2e4782))"
                
                if _0x3b6833 != 64 {
                    _0x59b81a = "\(_0x59b81a)\(chr(_0x2c0540))"
                }
                
                if _0x3b6833 != 64 {
                    _0x59b81a = "\(_0x59b81a)\(chr(_0x5a46ef))"
                }
            }
        }
        
        return _0x59b81a
    }
    
    func isParserRecommended(forPurpose _: Purpose) -> Bool {
        // Streamango is no longer available
        return false
    }
}
