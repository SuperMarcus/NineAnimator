//
//  RapidVideoParser.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/7/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import Foundation
import Alamofire
import SwiftSoup
import AVKit

class RapidVideoParser: VideoProviderParser {
    func parse(url: URL, with session: Alamofire.SessionManager, onCompletion handler: @escaping NineAnimatorCallback<AVPlayerItem>) -> NineAnimatorAsyncTask {
        let additionalHeaders: Alamofire.HTTPHeaders = [
            "Referer": url.absoluteString
        ]
        return session.request(url, headers: additionalHeaders).responseString {
            response in
            guard let value = response.value else {
                debugPrint("Error: \(response.error?.localizedDescription ?? "Unknown")")
                handler(nil, NineAnimatorError.responseError("response error: \(response.error?.localizedDescription ?? "Unknown")"))
                return
            }
            do{
                let bowl = try SwiftSoup.parse(value)
                let sourceString = try bowl.select("video>source").attr("src")
                guard let sourceUrl = URL(string: sourceString) else {
                    handler(nil, NineAnimatorError.responseError("unable to convert video source to URL"))
                    return
                }
                
                debugPrint("Info: (RapidVideo Parser) found asset at \(sourceUrl.absoluteString)")
                
                let asset = AVURLAsset(url: sourceUrl, options: ["AVURLAssetHTTPHeaderFieldsKey":additionalHeaders])
                let item = AVPlayerItem(asset: asset)
                
                handler(item, nil)
            }catch{ handler(nil, error) }
        }
    }
}
