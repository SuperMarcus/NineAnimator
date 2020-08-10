//
//  FacebookParser.swift
//  NineAnimator
//
//  Created by Uttiya Dutta on 2020-08-09.
//  Copyright © 2020 Marcus Zhou. All rights reserved.
//

import Foundation
import Alamofire

class FacebookParser: VideoProviderParser {
    var aliases: [String] { [ "fdserver" ] }
    
    static let videoSourceRegex = try! NSRegularExpression(
        pattern: "\"file\":\"([^\"]+)",
        options: .caseInsensitive
    )
    
    func parse(episode: Episode, with session: Session, forPurpose purpose: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        if episode.target.host?.lowercased() == "embed.streamx.me" {
            return parseWithStreamX(episode: episode, with: session, onCompletion: handler)
        } else {
            // Currently only supports parsing from StreamX domain
            return NineAnimatorPromise.fail(NineAnimatorError.providerError(
                "No parser compatible with Episode's target domain"
            )).handle(handler)
        }
    }
    
    func parseWithStreamX(episode: Episode, with session: Session, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        session.request(
            episode.target,
            headers: [ "Referer": episode.parent.link.link.absoluteString ]
        ).responseString {
            response in
            do {
                let responseContent: String
                switch response.result {
                case let .success(c): responseContent = c
                case let .failure(error): throw error
                }
                
                // Find Source URL
                let sourceURLString = try FacebookParser.videoSourceRegex.firstMatch(in: responseContent)
                    .tryUnwrap()
                    .firstMatchingGroup
                    .tryUnwrap()
                    .replacingOccurrences(of: #"\/"#, with: "/") // Remove "/" escape characters
                
                let sourceURL = try URL(string: sourceURLString).tryUnwrap()
                
                Log.info("(FacebookParser) found asset at %@", sourceURL)
                
                handler(BasicPlaybackMedia(
                    url: sourceURL,
                    parent: episode,
                    contentType: "video/mp4",
                    headers: [:],
                    isAggregated: false
                ), nil)
            } catch { handler(nil, error) }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true // Seems to be reliable
    }
}
