//
//  Anime.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/4/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit
import Alamofire

struct AnimeLink: Alamofire.URLConvertible {
    var title: String
    var link: URL
    var image: URL
    
    init(title: String, link: URL, image: URL) {
        self.title = title
        self.link = link
        self.image = image
    }
    
    func asURL() -> URL { return link }
}

extension AnimeLink: Equatable {
    static func == (lhs: AnimeLink, rhs: AnimeLink) -> Bool {
        return lhs.link == rhs.link
    }
}
