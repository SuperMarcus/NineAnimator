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

/// Server parser for VidStream
/// Credits to Jack_ the Awsomedude
class VidStreamParser: VideoProviderParser {
    var aliases: [String] { [] }
    
    private static let apiBaseSourceURL = URL(string: "https://vidstream.pro/info/")!
    
    private struct APIResponse: Codable {
        let success: Bool
        let media: Media
    }

    private struct Media: Codable {
        let sources: [Source]
    }

    private struct Source: Codable {
        let file: String
    }

    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise<PlaybackMedia> {
            callback in
            let episodeComponents = episode.target.pathComponents
            guard episodeComponents.count == 3 else {
                handler(nil, NineAnimatorError.urlError)
                return nil
            }
            let resourceIdentifier = episodeComponents[2]
            
            let additionalResourceRequestHeaders: HTTPHeaders = [
                "Referer": episode.parent.link.link.absoluteString
            ]
            
            // Make the request to the URL
            return session.request(
                VidStreamParser.apiBaseSourceURL.appendingPathComponent(resourceIdentifier),
                headers: additionalResourceRequestHeaders
            ) .responseJSON {
                response in
                switch response.result {
                case .success(let responseDictionary as NSDictionary):
                    do {
                        let decodedResponse = try DictionaryDecoder().decode(
                            APIResponse.self,
                            from: responseDictionary
                        )
                        let selectedSource = try decodedResponse
                            .media
                            .sources
                            .last
                            .tryUnwrap(.providerError("No available source was found"))
                        let resourceUrl = try URL(string: selectedSource.file).tryUnwrap(.urlError)
                        
                        Log.info("(VidStream Parser) found asset at %@", resourceUrl.absoluteString)
                        
                        callback(BasicPlaybackMedia(
                            url: resourceUrl,
                            parent: episode,
                            contentType: "application/vnd.apple.mpegurl",
                            headers: [:],
                            isAggregated: true
                        ), nil)
                    } catch { callback(nil, error) }
                default: callback(nil, response.error ?? NineAnimatorError.unknownError)
                }
            }
        } .handle(handler)
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        purpose == .playback
    }
}
