//
//  OpenStreamParser.swift
//  NineAnimator
//
//  Created by Uttiya Dutta on 2020-08-11.
//  Copyright © 2020 Marcus Zhou. All rights reserved.
//

import Foundation
import Alamofire

class OpenStreamParser: VideoProviderParser {
    var aliases: [String] { [] }
    
    static let streamXVideoSource = try! NSRegularExpression(
        pattern: #""file":"([^"]+)"#,
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
            headers: [ "referer": episode.parent.link.link.absoluteString ]
        ).responseString {
            response in
            do {
                let responseContent: String
                switch response.result {
                case let .success(c): responseContent = c
                case let .failure(error): throw error
                }
                
                let sourceURLString = try (OpenStreamParser.streamXVideoSource.firstMatch(in: responseContent)?
                    .firstMatchingGroup?
                    .replacingOccurrences(of: #"\/"#, with: #"/"#))
                    .tryUnwrap(.providerError("Unable to find the streaming resource"))
                
                let sourceURL = try URL(string: sourceURLString).tryUnwrap(.urlError)
                
                Log.info("(OpenStream Parser) found asset at %@", sourceURL.absoluteString)
                
                handler(BasicPlaybackMedia(
                    url: sourceURL,
                    parent: episode,
                    contentType: "video/mp4",
                    headers: [:],
                    isAggregated: true
                ), nil)
                
            } catch { handler(nil, error) }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
