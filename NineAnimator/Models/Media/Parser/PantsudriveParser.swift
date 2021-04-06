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

class PantsudriveParser: VideoProviderParser {
    var aliases: [String] { [] }
    
    private static let apiURL = URL(string: "https://play.api-web.site/anime/videourl.php")!
    
    private func getVideoID(url: URL) -> String? {
        guard let url = URLComponents(string: url.absoluteString) else {
            return nil
        }
        return url.queryItems?.first { $0.name == "id" }?.value
    }
    
    private struct APIResponse: Codable {
        let url: [PlaybackFiles]
    }
    
    private struct PlaybackFiles: Codable {
        let file: String
        let label: String
    }
    
    func parse(episode: Episode, with session: Session, forPurpose purpose: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise<PlaybackMedia> {
            callback in
            guard let videoID = self.getVideoID(url: episode.target) else {
                handler(nil, NineAnimatorError.decodeError("Video ID"))
                return nil
            }
            
            return session.request(
                PantsudriveParser.apiURL,
                method: .post,
                parameters: [ "id": videoID ],
                headers: [
                    "x-requested-with": "XMLHttpRequest",
                    "referer": episode.target.absoluteString
                ]
            ).responseDecodable(of: APIResponse.self) {
                response in
                switch response.result {
                case .success(let response):
                    do {
                        let videoURLString = try response
                            .url
                            .first
                            .tryUnwrap(.decodeError("First Video URL"))
                            .file
                        
                        let videoURL = try URL(string: videoURLString)
                            .tryUnwrap(.decodeError("Video URL"))
                        
                        callback(
                            BasicPlaybackMedia(
                                url: videoURL,
                                parent: episode,
                                contentType: "video/mp4",
                                headers: [:],
                                isAggregated: false
                        ), nil)
                    } catch { callback(nil, error) }
                default: callback(nil, response.error ?? NineAnimatorError.unknownError)
                }
            }
        }.handle(handler)
    }
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
