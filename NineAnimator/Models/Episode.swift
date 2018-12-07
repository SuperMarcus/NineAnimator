//
//  Episode.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/6/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import Foundation
import Alamofire
import SwiftSoup

struct Episode {
    let link: Anime.EpisodeLink
    let target: URL
    
    var name: String { return link.name }
    var parentLink: AnimeLink { return link.parent }
    
    private var _parent: Anime?
    
    init(_ link: Anime.EpisodeLink, on target: URL, parent: Anime? = nil) {
        self.link = link
        self.target = target
        self._parent = parent
    }
    
    func parent(onCompletion handler: @escaping NineAnimatorCallback<Anime>){
        if let parent = _parent { handler(parent, nil) }
        else { NineAnimator.default.anime(with: link.parent, onCompletion: handler) }
    }
}

extension Anime {
    func episode(with link: EpisodeLink, onCompletion handler: @escaping NineAnimatorCallback<Episode>) {
        let ajaxHeaders: Alamofire.HTTPHeaders = [ "Referer": self.link.link.absoluteString ]
        
        session
            .request(AjaxPath.episode(for: link.identifier, on: link.server), headers: ajaxHeaders)
            .responseJSON{
                response in
                if case let .failure(error) = response.result {
                    debugPrint("Error: Failiure on request: \(error)")
                    handler(nil, error)
                    return
                }
                
                guard let responseJson = response.value as? NSDictionary else {
                    debugPrint("Error: No content received")
                    handler(nil, NineAnimatorError.responseError("no content received from server"))
                    return
                }
                
                guard let targetString = responseJson["target"] as? String,
                      let target = URL(string: targetString) else {
                    debugPrint("Error: Target not defined or is invalid in response")
                    handler(nil, NineAnimatorError.responseError("target url not defined or invalid"))
                    return
                }
                
                handler(Episode(link, on: target, parent: self), nil)
        }
    }
}
