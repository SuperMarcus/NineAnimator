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
    
    private let apiPath = URL(string: "https://streamsb.net/play")!
    
    private let videoSourceRegex = try! NSRegularExpression(
        pattern: #"file:"([^"]+)"#,
        options: .caseInsensitive
    )
    
    private let embedIDRegex = try! NSRegularExpression(
        pattern: #"(?<=embed-).+?(?=\.)"#,
        options: .caseInsensitive
    )
    
    private func retrieveId(from path: String) -> String? {
        self.embedIDRegex
            .firstMatch(in: path)?
            .first
    }
    
    func parse(episode: Episode, with session: Session, forPurpose purpose: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let videoID = retrieveId(from: episode.target.absoluteString) ?? episode.target.absoluteString
        let requestURL = apiPath.appendingPathComponent(videoID)
        return session.request(
            requestURL,
            parameters: [ "auto": 1, "referer": episode.link.identifier ]
        ).responseString {
            response in
            do {
                let responseContent: String
                switch response.result {
                case let .success(c): responseContent = c
                case let .failure(error): throw error
                }
                
                let decodedString = try PackerDecoder().decode(responseContent)
                
                let videoURLString = try (self.videoSourceRegex
                    .firstMatch(in: decodedString)?
                    .firstMatchingGroup)
                    .tryUnwrap(.providerError("Could not get Video URL from Regex"))
                
                let videoURL = try URL(string: videoURLString).tryUnwrap()
                
                handler(BasicPlaybackMedia(
                    url: videoURL,
                    parent: episode,
                    contentType: "application/vnd.apple.mpegurl",
                    headers: ["Referer": episode.target.absoluteString],
                    isAggregated: true
                ), nil)
            } catch { handler(nil, error) }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
