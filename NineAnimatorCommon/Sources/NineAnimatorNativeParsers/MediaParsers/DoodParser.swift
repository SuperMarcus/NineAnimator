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

class DoodParser: VideoProviderParser {
    var aliases: [String] { [] }
    
    let videoSourceRegex = try! NSRegularExpression(
        pattern: #"\$\.get\('(\/pass_md5[^']+)"#,
        options: .caseInsensitive
    )
    
    func parse(episode: Episode, with session: Session, forPurpose purpose: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        session.request(
            episode.target,
            headers: [ "Referer": episode.parentLink.link.absoluteString ]
        ).responseString {
            response in
            do {
                let responseContent: String
                switch response.result {
                case let .success(c): responseContent = c
                case let .failure(error): throw error
                }
                
                let md5UrlString = try (self.videoSourceRegex
                    .firstMatch(in: responseContent)?
                    .firstMatchingGroup)
                    .tryUnwrap(.providerError("Could not get Video URL from Regex"))
                
                let md5URL = try URL(
                    string: "https://dood.to" + md5UrlString
                ).tryUnwrap()
                
                // Extract the token from the URL
                let md5Token = md5URL.lastPathComponent
                
                session.request(
                    md5URL,
                    headers: [
                        "Referer": episode.target.absoluteString,
                        "X-Requested-With": "XMLHttpRequest"
                    ]
                ).responseString {
                    // The response content is the partial link to the video
                    secondResponse in
                    do {
                        let responseContent: String
                        switch secondResponse.result {
                        case let .success(c): responseContent = c
                        case let .failure(error): throw error
                        }
                        
                        // Add 10 random letters to the url base
                        // the token extracted from before
                        // and an expiry date containing the current date
                        let letters = "abcdefghijklmnopqrstuvwxyz0123456789"
                        let randomLetters = String((0..<10).map { _ in letters.randomElement()! })
                        let dateString = String(Date().timeIntervalSince1970)
                        
                        let directVideoURLString = "\(responseContent + randomLetters)?token=\(md5Token)&expiry=\(dateString)"
                        
                        let directVideoURL = try URL(string: directVideoURLString)
                            .tryUnwrap(.providerError("Could not generate direct Video Link."))
                        
                        handler(BasicPlaybackMedia(
                            url: directVideoURL,
                            parent: episode,
                            contentType: "video/mp4",
                            headers: [ "Referer": "https://dood.to/"],
                            isAggregated: false
                        ), nil)
                    } catch { handler(nil, error) }
                }
            } catch { handler(nil, error) }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        purpose != .googleCast
    }
}
