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
import AVKit
import Foundation
import JavaScriptCore

class OpenLoadParser: VideoProviderParser {
    static let longStringRegex = try! NSRegularExpression(pattern: "<p style=\"\" id=[^>]*>([^<]*)<\\/p>", options: .caseInsensitive)
    static let key1Regex = try! NSRegularExpression(pattern: "_0x45ae41\\[_0x5949\\('0xf'\\)\\]\\(_0x30725e,(.+)\\),_1x4bfb36", options: .caseInsensitive)
    static let key2Regex = try! NSRegularExpression(pattern: "_1x4bfb36=(parseInt\\(.+,\\d+\\)(-\\d+));", options: .caseInsensitive)
    static let hostUrl = try! NSRegularExpression(pattern: "(.+)\\/embed\\/.+\\/", options: .caseInsensitive)
    
    func parse(episode: Episode, with session: SessionManager, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        return session.request(episode.target).responseString {
            response in
            guard let text = response.value else {
                Log.error(response.error)
                return handler(nil, NineAnimatorError.responseError(
                    "response error: \(response.error?.localizedDescription ?? "Unknown")"
                ))
            }
            
            let longStringMatches = OpenLoadParser.longStringRegex.matches(in: text, options: [], range: text.matchingRange)
            guard let longStringMatch = longStringMatches.first else { return handler(nil, NineAnimatorError.responseError(
                "Couldn't find long string"
            )) }
            
            let key1Matches = OpenLoadParser.key1Regex.matches(in: text, options: [], range: text.matchingRange)
            guard let key1Match = key1Matches.first else { return handler(nil, NineAnimatorError.responseError(
                "Couldn't find Key 1"
            )) }
            
            let key2Matches = OpenLoadParser.key2Regex.matches(in: text, options: [], range: text.matchingRange)
            guard let key2Match = key2Matches.first else { return handler(nil, NineAnimatorError.responseError(
                "Couldn't find Key 2"
            )) }
            
            let urlMatches = OpenLoadParser.hostUrl.matches(in: episode.target.absoluteString, options: [], range: episode.target.absoluteString.matchingRange)
            guard let urlMatch = urlMatches.first else { return handler(nil, NineAnimatorError.responseError(
                "Couldn't find url"
            )) }
            
            let context = JSContext()!
            
            let encryptedString = text[longStringMatch.range(at: 1)]
            let Key1 = context.evaluateScript(text[key1Match.range(at: 1)])
            let Key2 = context.evaluateScript(text[key2Match.range(at: 1)])
            
            
            let streamUrl = self.openload(longstring: encryptedString, key1: (Key1?.toInt32())!, key2: (Key2?.toInt32())!)
            
            guard let sourceURL = URL(string: "\(episode.target.absoluteString[urlMatch.range(at: 1)])/stream/\(streamUrl)") else {
                return handler(nil, NineAnimatorError.responseError(
                    "source url not recongized"
                ))
            }
            
            Log.info("(OpenLoad Parser) found %@", sourceURL)
            
            handler(BasicPlaybackMedia(
                url: sourceURL,
                parent: episode,
                contentType: "video/mp4",
                headers: [
                    "User-Agent": self.defaultUserAgent
                ],
                isAggregated: false), nil)
        }
    }
    
    func openload(longstring: String, key1: Int32, key2: Int32) -> String {
        var streamUrl = ""
        var encryptString = ""
        var hexByteArr: [Int] = []
        
        var i = 0
        while i < 72 {
            hexByteArr.append(Int(longstring[i..<i+8], radix: 16)!)
            
            i = i + 8
        }
        
        encryptString = longstring[72...]
        
        var iterator = 0
        var arrIterator = 0
        while iterator < encryptString.count {
            var maxHex = 64
            var value = 0
            var currHex = 255
            
            var byteIterator = 0
            
            while currHex >= maxHex {
                if (iterator + 1 >= encryptString.count) {
                    maxHex = 143
                }
                
                currHex = Int(encryptString[iterator..<iterator+2], radix: 16)!
                value = value + (currHex & 63) << byteIterator
                
                byteIterator = byteIterator + 6
                iterator = iterator + 2
            }
            
            let bytes = value ^ hexByteArr[arrIterator % 9] ^ Int(key1) ^ Int(key2)
            var usedBytes = maxHex * 2 + 127
            
            var i = 0
            while i < 4 {
                let urlChar = String(UnicodeScalar(UInt8( ((bytes & usedBytes) >> (8 * i)) - 1 )))
                
                if (urlChar != "$") {
                    streamUrl.append(urlChar)
                }
                
                usedBytes = usedBytes << 8
                i = i + 1
            }
            arrIterator = arrIterator + 1
        }
        return streamUrl
    }
}
