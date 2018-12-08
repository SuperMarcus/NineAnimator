//
//  VideoProviderParsers.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/7/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit
import Alamofire
import AVKit

protocol VideoProviderParser {
    func parse(url: URL, with: Alamofire.SessionManager, onCompletion: @escaping NineAnimatorCallback<AVPlayerItem>) -> NineAnimatorAsyncTask
}

class VideoProviderRegistry {
    static let `default`: VideoProviderRegistry = {
        let defaultProvider = VideoProviderRegistry()
        
        defaultProvider.register(MyCloudParser(), for: "28")
        defaultProvider.register(RapidVideoParser(), for: "33")
        defaultProvider.register(StreamangoParser(), for: "34")
        
        return defaultProvider
    }()
    
    private var providers = [(server: Anime.ServerIdentifier, provider: VideoProviderParser)]()
    
    func register(_ provider: VideoProviderParser, for server: Anime.ServerIdentifier) {
        providers.append((server, provider))
    }
    
    func provider(for server: Anime.ServerIdentifier) -> VideoProviderParser? {
        for provider in providers {
            if provider.server == server { return provider.provider }
        }
        return nil
    }
}
