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

/**
 A container for all possible links
 */
public enum AnyLink {
    case anime(AnimeLink)
    case episode(EpisodeLink)
    case listingReference(ListingAnimeReference)
}

public struct AnimeLink {
    public var title: String
    public var link: URL
    public var image: URL
    public var source: Source
    
    public init(title: String, link: URL, image: URL, source: Source) {
        self.title = title
        self.link = link
        self.image = image
        self.source = source
    }
}

extension AnyLink: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .anime(link): hasher.combine(link)
        case let .episode(link): hasher.combine(link)
        case let .listingReference(reference): hasher.combine(reference)
        }
    }
}

extension AnimeLink: URLConvertible {
    public func asURL() -> URL { link }
}

extension AnimeLink: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(link)
    }
}

extension AnimeLink: Codable {
    public enum CodingKeys: String, CodingKey {
        case title
        case link
        case image
        case source
    }
    
    public init(from decoder: Decoder) throws {
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
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(title, forKey: .title)
        try values.encode(link, forKey: .link)
        try values.encode(image, forKey: .image)
        try values.encode(source.name, forKey: .source)
    }
    
    /// A shortcut for source.anime(from:handler:)
    @available(*, deprecated, message: "Use NineAnimator.anime(_:) instead")
    public func retrieve(_ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask? {
        NineAnimator.default.anime(with: self, onCompletion: handler)
    }
    
    /// Return a `NineAnimatorPromise` for retrieving the `Anime` object
    @available(*, deprecated, message: "Use NineAnimator.anime() instead")
    public func retrieve() -> NineAnimatorPromise<Anime> {
        NineAnimator.default.anime(with: self)
    }
}

extension AnimeLink: Equatable {
    public static func == (lhs: AnimeLink, rhs: AnimeLink) -> Bool {
        lhs.link == rhs.link
    }
}

public struct EpisodeLink: Codable, Hashable {
    public let identifier: Anime.EpisodeIdentifier
    public let name: String
    public let server: Anime.ServerIdentifier
    public let parent: AnimeLink
    
    public init(identifier: Anime.EpisodeIdentifier, name: String, server: Anime.ServerIdentifier, parent: AnimeLink) {
        self.identifier = identifier
        self.name = name
        self.server = server
        self.parent = parent
    }
}

// Hashable
public extension EpisodeLink {
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(server)
        hasher.combine(parent)
    }
}

// Progress
public extension EpisodeLink {
    var playbackProgress: Double {
        let trackingContext = NineAnimator.default.trackingContext(for: parent)
        let progress = trackingContext.playbackProgress(for: self)
        return progress
    }
}

// Access basic info of the link
public extension AnyLink {
    // The name of this link
    var name: String {
        switch self {
        case .anime(let anime): return anime.title
        case .episode(let episode): return episode.name
        case .listingReference(let reference): return reference.name
        }
    }
    
    // The artwork url of this link, if it has any
    var artwork: URL? {
        switch self {
        case .anime(let anime): return anime.image
        case .episode(let episode): return episode.parent.image
        case .listingReference(let reference): return reference.artwork
        }
    }
}
