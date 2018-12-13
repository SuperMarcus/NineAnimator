//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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

import UIKit
import Alamofire

struct AnimeLink {
    var title: String
    var link: URL
    var image: URL
    var source: Source
}
extension AnimeLink: URLConvertible {
    func asURL() -> URL { return link }
}

extension AnimeLink: Codable {
    enum CodingKeys: String, CodingKey {
        case title = "title"
        case link = "link"
        case image = "image"
        case source = "source"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decode(String.self, forKey: .title)
        link = try values.decode(URL.self, forKey: .link)
        image = try values.decode(URL.self, forKey: .image)
        
        let sourceName = try values.decode(String.self, forKey: .source)
        guard let source = NineAnimator.default.source(with: sourceName) else {
            throw NineAnimatorError.decodeError
        }
        
        self.source = source
    }
    
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(title, forKey: .title)
        try values.encode(link, forKey: .link)
        try values.encode(image, forKey: .image)
        try values.encode(source.name, forKey: .source)
    }
}

extension AnimeLink: Equatable {
    static func == (lhs: AnimeLink, rhs: AnimeLink) -> Bool {
        return lhs.link == rhs.link
    }
}

struct EpisodeLink: Equatable, Codable {
    let identifier: Anime.EpisodeIdentifier
    let name: String
    let server: Anime.ServerIdentifier
    let parent: AnimeLink
}

extension EpisodeLink {
    static func == (lhs: EpisodeLink, rhs: EpisodeLink) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}
