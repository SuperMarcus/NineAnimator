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

class XStreamParser: VideoProviderParser {
    var aliases: [String] { return [ "XStream", "XStreamCDN", "fembed" ] }
    
    private static let apiBaseSourceURL = URL(string: "https://www.xstreamcdn.com/api/source/")!
    
    private struct SourcesAPIResponse: Codable {
        var success: Bool
        var data: [Source]
    }
    
    private struct Source: Codable {
        var file: String
        var label: String
        var type: String
    }
    
    func parse(episode: Episode, with session: SessionManager, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        return NineAnimatorPromise<PlaybackMedia> {
            callback in
            let episodeComponents = episode.target.pathComponents
            guard episodeComponents.count == 3 else {
                handler(nil, NineAnimatorError.urlError)
                return nil
            }
            let resourceIdentifier = episodeComponents[2]
            
            // Make the request to the URL
            return session.request(
                XStreamParser.apiBaseSourceURL.appendingPathComponent(resourceIdentifier),
                method: .post,
                parameters: [ "r": "", "d": "www.xstreamcdn.com" ],
                encoding: URLEncoding.default
            ) .responseJSON {
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
                        
                        Log.info("(XStream Parser) found asset at %@", resourceUrl.absoluteString)
                        
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
        } .handle(handler)
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        return true
    }
}
