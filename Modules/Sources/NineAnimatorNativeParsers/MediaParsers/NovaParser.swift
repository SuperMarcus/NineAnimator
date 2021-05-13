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
import NineAnimatorCommon

class NovaParser: VideoProviderParser {
    var aliases: [String] {
        [ "Nova", "Nova Server" ]
    }
    
    private struct SourcesAPIResponse: Codable {
        var success: Bool
        var data: [Source]
    }
    
    private struct Source: Codable {
        var file: String
        var label: String
        var type: String
    }
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion callback: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let videoIdentifier = episode.target.lastPathComponent
        guard let sourceInfoUrl = URL(string: "https://www.novelplanet.me/api/source/\(videoIdentifier)")
            else { return NineAnimatorPromise.fail(NineAnimatorError.urlError).handle(callback) }
        
        return session.request(sourceInfoUrl, method: .post).responseJSON {
            response in
            switch response.result {
            case .success(let responseDictionary as NSDictionary):
                do {
                    let decodedResponse = try DictionaryDecoder().decode(
                        SourcesAPIResponse.self,
                        from: responseDictionary
                    )
                    let selectedSource = try decodedResponse
                        .data
                        .last
                        .tryUnwrap(.providerError("No available source was found"))
                    let resourceUrl = try URL(string: selectedSource.file).tryUnwrap(.urlError)
                    let isHLSAsset = selectedSource.type != "mp4"
                    
                    Log.info("(Nova Parser) found asset at %@", resourceUrl.absoluteString)
                    
                    callback(BasicPlaybackMedia(
                        url: resourceUrl,
                        parent: episode,
                        contentType: isHLSAsset ? "application/vnd.apple.mpegurl" : "video/mp4",
                        headers: [:],
                        isAggregated: isHLSAsset
                    ), nil)
                } catch { callback(nil, error) }
            default: callback(nil, response.error ?? NineAnimatorError.unknownError)
            }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
