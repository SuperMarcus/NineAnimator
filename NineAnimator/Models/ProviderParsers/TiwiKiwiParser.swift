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

class TiwiKiwiParser: VideoProviderParser {
    static let jwPlayerOptionRegex = try! NSRegularExpression(pattern: "'([^']+)'\\.split", options: .caseInsensitive)
    static let flowPlayerPropertyURLRegex = try! NSRegularExpression(pattern: "src:\\s*\"([^\"]+)\"", options: .caseInsensitive)
    static let flowPlayerBaseURLRegex = try! NSRegularExpression(pattern: "BaseURL>([^<]+)", options: .caseInsensitive)
    
    func parse(episode: Episode,
               with session: SessionManager,
               onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        let headers = [
            "User-Agents": defaultUserAgent,
            "Origin": episode.target.absoluteString
        ]
        let task = NineAnimatorMultistepAsyncTask()
        task.add(session.request(episode.target, headers: headers).responseString {
            [weak task, session] response in
            guard let task = task else { return }
            
            let playbackHeaders = [
                "Origin": episode.target.absoluteString,
                "User-Agent": self.defaultUserAgent
            ]
            
            guard let text = response.value else {
                Log.error(response.error)
                return handler(nil, NineAnimatorError.responseError(
                    "response error: \(response.error?.localizedDescription ?? "Unknown")"
                ))
            }
            
            var url: URL?
            
            if let match = TiwiKiwiParser.jwPlayerOptionRegex.matches(in: text, range: text.matchingRange).first {
                url = TiwiKiwiParser.assembleTwPlayerURL(for: text[match.range(at: 1)])
            }
            
            if url == nil, let match = TiwiKiwiParser.flowPlayerPropertyURLRegex.matches(in: text, range: text.matchingRange).last {
                Log.info("Info: This episode uses flow player. Tracing source URLs.")
                let propertyListUrl = text[match.range(at: 1)]
                return task.add(session.request(propertyListUrl, headers: headers).responseString {
                    response in
                    guard case .success(let playbackPropertyList) = response.result else {
                        return handler(nil, NineAnimatorError.responseError(
                            "unable to retrive playback media property list"
                        ))
                    }
                    let matches = TiwiKiwiParser.flowPlayerBaseURLRegex.matches(in: playbackPropertyList, range: playbackPropertyList.matchingRange)
                    guard let baseUrl = matches.first else {
                        return handler(nil, NineAnimatorError.responseError(
                            "unable to retrive media base url from property list"
                        ))
                    }
                    guard let propertyUrlBaseStopIndex = propertyListUrl.lastIndex(of: "/")
                        else { return handler(nil, NineAnimatorError.urlError) }
                    let resourceUrlBase = propertyListUrl[..<propertyUrlBaseStopIndex]
                    let resourceUrlString = "\(resourceUrlBase)/\(playbackPropertyList[baseUrl.range(at: 1)])"
                    
                    guard let sourceURL = URL(string: resourceUrlString) else {
                        return handler(nil, NineAnimatorError.responseError(
                            "source url not recongized"
                        ))
                    }
                    
                    Log.info("(Tiwi.Kiwi Parser) found asset at %@", sourceURL.absoluteString)
                    
                    //This also doen't work with chromecast
                    handler(BasicPlaybackMedia(
                        url: sourceURL,
                        parent: episode,
                        contentType: "video/mp4",
                        headers: playbackHeaders,
                        isAggregated: false), nil)
                })
            }
            
            guard let sourceURL = url else {
                return handler(nil, NineAnimatorError.responseError(
                    "source url not recongized"
                ))
            }
            
            Log.info("(Tiwi.Kiwi Parser) found asset at %@", sourceURL.absoluteString)
            
            //This also doen't work with chromecast
            handler(BasicPlaybackMedia(
                url: sourceURL,
                parent: episode,
                contentType: "video/mp4",
                headers: playbackHeaders,
                isAggregated: false), nil)
        })
        return task
    }
    
    fileprivate static func assembleTwPlayerURL(for playerOptionsString: String) -> URL? {
        let playerOptions = playerOptionsString.split(separator: "|")
        
        let serverPrefix = playerOptions[29]
        let mediaIdentifier = playerOptions[118]
        
        return URL(string: "https://\(serverPrefix).tiwicdn.net/\(mediaIdentifier)/v.mp4")
    }
}
