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

class StreamSBParser: VideoProviderParser {
    var aliases: [String] { [] }

    private struct StreamSBAPIResponse: Codable {
        let streamData: StreamData
        let statusCode: Int
    }

    private struct StreamData: Codable {
        let file: String?
        let cdnImg: String
        let logo: Logo
        let hash, length: String
        let subs: [String?]
        let title, id: String
        let backup: String
        let qlabel: [String: String]
    }

    private struct Logo: Codable {
        let hide: String
        let url: String
    }
    
    private let apiPath: String = "https://watchsb.com/sourcesx38/7361696b6f757c7c\("HEXVIDEOID")7c7c7361696b6f757c7c73747265616d7362/7361696b6f757c7c363136653639366436343663363136653639366436343663376337633631366536393664363436633631366536393664363436633763376336313665363936643634366336313665363936643634366337633763373337343732363536313664373336327c7c7361696b6f757c7c73747265616d7362"
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise<PlaybackMedia> {
            callback in

            let videoID = episode.target.deletingPathExtension().lastPathComponent
            guard episode.target.pathComponents.count == 3 else {
                handler(nil, NineAnimatorError.urlError)
                return nil
            }
            
            let hexVideoID = Data(videoID.utf8).map {
                String(format: "%x", $0 )
            }.joined()
            let sourceURLString = self.apiPath.replacingOccurrences(of: "HEXVIDEOID", with: hexVideoID)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Make the request to the URL
            return session.request(
                sourceURLString,
                headers: [
                    "watchsb": "streamsb",
                    "Referer": episode.target.absoluteString
                ]
            ) .responseDecodable(of: StreamSBAPIResponse.self, decoder: decoder) {
                response in
                switch response.result {
                case .success(let decodedResponse):
                    do {
                        let streamData = decodedResponse.streamData

                        let resourceUrl = try URL(string: streamData.file ?? streamData.backup).tryUnwrap(.urlError)

                        Log.info("(StreamSB Parser) found asset at %@", resourceUrl.absoluteString)

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
