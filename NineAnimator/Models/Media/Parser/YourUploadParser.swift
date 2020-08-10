//
//  YourUploadParser.swift
//  NineAnimator
//
//  Created by Uttiya Dutta on 2020-08-10.
//  Copyright © 2020 Marcus Zhou. All rights reserved.
//

import Foundation
import Alamofire

class YourUploadParser: VideoProviderParser {
    var aliases: [String] { [] }
    
    static let videoSourceRegex = try! NSRegularExpression(
        pattern: #"file: '([^']+)"#,
        options: .caseInsensitive
    )
    
    func parse(episode: Episode, with session: Session, forPurpose purpose: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        session.request(episode.target).responseString {
            response in
            do {
                let responseContent: String
                switch response.result {
                case let .success(c): responseContent = c
                case let .failure(error): throw error
                }
                
                let sourceURLString = try (YourUploadParser
                    .videoSourceRegex
                    .firstMatch(in: responseContent)?
                    .firstMatchingGroup)
                    .tryUnwrap(.providerError("Unable to find the streaming resource"))
                
                let sourceURL = try URL(string: sourceURLString).tryUnwrap(.urlError)
                
                Log.info("(YourUpload Parser) found asset at %@", sourceURL.absoluteString)
                
                handler(BasicPlaybackMedia(
                    url: sourceURL,
                    parent: episode,
                    contentType: "video/mp4",
                    headers: [ "referer": episode.target.absoluteString ],
                    isAggregated: false), nil)
            } catch { handler(nil, error) }
        }
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        true
    }
}
