//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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
