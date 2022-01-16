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
import NineAnimatorCommon

/// Server playback asset parser for RapidCloud
class RapidCloudParser: VideoProviderParser {
    var aliases: [String] { [ "RapidCloud", "Rapid Cloud", "rapidcloud" ] }
    
    private static let apiBaseSourceURL = URL(string: "https://rapid-cloud.ru/ajax/embed-6/getSources")!
    
    private struct SourcesAPIResponse: Codable {
        let sources: [Source]
        let sourcesBackup: [String] // idk what's in this empty array
        let tracks: [Track]
    }

    private struct Source: Codable {
        let file: String
        let type: String
    }
    
    private struct Track: Codable {
        let file: String
        let kind: String
        let label: String?
    }
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise<PlaybackMedia> {
            callback in
            let episodeComponents = episode.target.pathComponents
            
            print(episodeComponents)
            
            guard episodeComponents.count == 3 else {
                handler(nil, NineAnimatorError.urlError)
                return nil
            }
            let resourceIdentifier = episodeComponents[2]
            
            // Make the request to the URL
            return session.request(
                RapidCloudParser.apiBaseSourceURL,
                parameters: [
                    "id": resourceIdentifier
                ]
            ) .responseDecodable(of: SourcesAPIResponse.self) {
                response in
                switch response.result {
                case .success(let decodedResponse):
                    do {
                        let selectedSource = try decodedResponse
                            .sources
                            .first
                            .tryUnwrap(.providerError("No available source was found"))
                        let resourceUrl = try URL(string: selectedSource.file).tryUnwrap(.urlError)
                        
                        Log.info("(RapidCloud Parser) found asset at %@", resourceUrl.absoluteString)
                        
                        // Need to figure out how to get subtitles working
                        /* let subtitles = try decodedResponse
                            .tracks[safe: 1]
                            .tryUnwrap(.providerError("No available subtitle was found"))
                        
                        Log.info("(RapidCloud Parser) found subtitle at %@", subtitles.file)
                        
                        callback(CompositionalPlaybackMedia(
                            url: resourceUrl,
                            parent: episode,
                            contentType: "application/vnd.apple.mpegurl",
                            headers: [:],
                            subtitles: [
                                (
                                    url: try URL(string: subtitles.file).tryUnwrap(),
                                    name: subtitles.kind,
                                    language: try subtitles.label.tryUnwrap()
                                )
                            ]
                        ), nil) */
                        
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
        true
    }
}
