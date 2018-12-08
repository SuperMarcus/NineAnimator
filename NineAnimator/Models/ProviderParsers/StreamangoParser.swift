//
//  StreamangoParser.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/7/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import Foundation
import Alamofire
import AVKit

class StreamangoParser: VideoProviderParser {
    static let obscuredVideoSourceRegex = try! NSRegularExpression(pattern: "src:\\s*d\\('([^']+)',\\s*([^)]+)\\)", options: .caseInsensitive)
    
    func parse(url: URL, with session: Alamofire.SessionManager, onCompletion handler: @escaping NineAnimatorCallback<AVPlayerItem>) -> NineAnimatorAsyncTask {
        let additionalHeaders: Alamofire.HTTPHeaders = [
            "Referer": url.absoluteString
        ]
        return session.request(url, headers: additionalHeaders).responseString {
            response in
            guard let text = response.value else {
                debugPrint("Error: \(response.error?.localizedDescription ?? "Unknown")")
                handler(nil, NineAnimatorError.responseError("response error: \(response.error?.localizedDescription ?? "Unknown")"))
                return
            }
            
            let matches = StreamangoParser.obscuredVideoSourceRegex.matches(in: text, options: [], range: text.matchingRange)
            
            guard let match = matches.first else {
                handler(nil, NineAnimatorError.responseError("no matches for source url"))
                return
            }
            
            let obscuredLink = text[match.range(at: 1)]
            
            guard let obscuredDecodingKey = Int(text[match.range(at: 2)]) else {
                handler(nil, NineAnimatorError.responseError("decoding key is not an integer"))
                return
            }
            
            let decodedLink = self.decode(obscured: obscuredLink, with: obscuredDecodingKey)
            
            
            guard let sourceUrl = URL(string: decodedLink.hasPrefix("//") ? "https:\(decodedLink)" : decodedLink) else {
                handler(nil, NineAnimatorError.responseError("source url not recongized"))
                return
            }
            
            debugPrint("Info: (Streamango Parser) found asset at \(sourceUrl.absoluteString)")
            
            let asset = AVURLAsset(url: sourceUrl, options: ["AVURLAssetHTTPHeaderFieldsKey":additionalHeaders])
            let item = AVPlayerItem(asset: asset)
            
            handler(item, nil)
        }
    }
    
    func decode(obscured: String, with code: Int) -> String {
        func charCode(_ c: Character) -> Int{
            let k = "=/+9876543210zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA"
            return k.distance(from: k.startIndex, to: k.range(of: String(c))!.lowerBound)
        }
        
        func chr(_ c: Int) -> Character {
            return Character(UnicodeScalar(c)!)
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
        
        let sequence = obscured.map{ return charCode($0) }
        
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
}
