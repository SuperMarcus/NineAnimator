//
//  MyCloudParser.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/7/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import Foundation
import Alamofire
import AVKit

class MyCloudParser: VideoProviderParser {
    static let videoIdentifierRegex = try! NSRegularExpression(pattern: "videoId:\\s*'([^']+)", options: .caseInsensitive)
    static let videoSourceRegex = try! NSRegularExpression(pattern: "\"file\":\"([^\"]+)", options: .caseInsensitive)
    
    func parse(url: URL, with session: Alamofire.SessionManager, onCompletion handler: @escaping NineAnimatorCallback<AVPlayerItem>) -> NineAnimatorAsyncTask {
        let additionalHeaders: Alamofire.HTTPHeaders = [
            "Referer": "https://www1.9anime.to/watch",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "User-Agnet": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.1 Safari/605.1.15",
            "Host": "mcloud.to"
        ]
        
        let playerAdditionalHeaders: Alamofire.HTTPHeaders = [
            "Referer": url.absoluteString,
            "User-Agnet": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.1 Safari/605.1.15"
        ]
        return session.request(url, headers: additionalHeaders).responseString {
            response in
            guard let text = response.value else {
                debugPrint("Error: \(response.error?.localizedDescription ?? "Unknown")")
                handler(nil, NineAnimatorError.responseError("response error: \(response.error?.localizedDescription ?? "Unknown")"))
                return
            }
            
            let matches = MyCloudParser.videoSourceRegex.matches(in: text, options: [], range: text.matchingRange)
            
            guard let match = matches.first else {
                handler(nil, NineAnimatorError.responseError("no matches for source url"))
                return
            }
            
            guard let sourceUrl = URL(string: text[match.range(at: 1)]) else {
                handler(nil, NineAnimatorError.responseError("source url not recongized"))
                return
            }
            
            debugPrint("Info: (MyCloud Parser) found asset at \(sourceUrl.absoluteString)")
            
            let asset = AVURLAsset(url: sourceUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": playerAdditionalHeaders])
            let item = AVPlayerItem(asset: asset)
            
            handler(item, nil)
        }
    }
}
