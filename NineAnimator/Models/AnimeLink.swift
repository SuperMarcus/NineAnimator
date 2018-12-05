//
//  Anime.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/4/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit

struct AnimeLink {
    var title: String
    var link: URL
    var image: URL
    
    var _uiImage: UIImage? = nil
    var uiImage: UIImage? {
        if _uiImage != nil { return _uiImage }
        
        guard let data = try? Data(contentsOf: image) else { return nil }
        
        return UIImage(data: data)
    }
    
    init(title: String, link: URL, image: URL) {
        self.title = title
        self.link = link
        self.image = image
        debugPrint("Loading image \(image)")
        self._uiImage = self.uiImage
    }
}
