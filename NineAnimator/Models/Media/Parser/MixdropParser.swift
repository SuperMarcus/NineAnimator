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

class MixdropParser: VideoProviderParser {
    var aliases: [String] { [] }
    
    static let videoURLParamsRegex = try! NSRegularExpression(
        pattern: "window.location = \"([^\"]+)",
        options: []
    )

    func parse(episode: Episode, with session: Session, forPurpose purpose: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let videoUrl = episode.target.absoluteString.hasPrefix("//") ?  "https:\(episode.target.absoluteString)" : episode.target.absoluteString

        guard let sourceInfoUrl = URL(string: videoUrl)
            else { return NineAnimatorPromise.fail(NineAnimatorError.urlError).handle(handler) }
        
        return NineAnimatorPromise {
            callback in session.request(sourceInfoUrl).responseString {
                callback($0.value, $0.error)
            }
        } .then {
            responseContent in
            
            let decodedScript = try PackerDecoder().decode(responseContent)
            let sourceMatchingExpr = try NSRegularExpression(
                pattern: "MDCore\\.wurl=\"([^\"]+)",
                options: []
            )
            
            let videoAssetUrlString = try sourceMatchingExpr
                .firstMatch(in: decodedScript)
                .tryUnwrap(.responseError("Video asset not found"))
                .firstMatchingGroup
                .tryUnwrap()
            
            let resourceUrl = try URL(string: videoAssetUrlString.hasPrefix("//") ?  "https:\(videoAssetUrlString)" : videoAssetUrlString).tryUnwrap(.urlError)
            
            Log.info("(Mixdrop Parser) found asset at %@", resourceUrl.absoluteString)
            
            return BasicPlaybackMedia(
                url: resourceUrl,
                parent: episode,
                contentType: "video/mp4",
                headers: [:],
                isAggregated: false
            )
        } .handle(handler)
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
