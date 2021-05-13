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

import Foundation

public extension AnyLink {
    /// Serialize the link to a NineAnimatorCloud redirection link
    var cloudRedirectionUrl: URL {
        let redirectionBaseUrl = NineAnimatorCloud
            .baseUrl
            .appendingPathComponent("/api/redirect")
        let encodingParameters: SerializedLinkParameters
        
        switch self {
        case let .episode(episodeLink):
            encodingParameters = SerializedLinkParameters(fromEpisodeLink: episodeLink)
        case let .anime(animeLink):
            encodingParameters = SerializedLinkParameters(fromAnimeLink: animeLink)
        case let .listingReference(reference):
            encodingParameters = SerializedLinkParameters(fromReference: reference)
        }
        
        let encodedParameters: NSDictionary = try! DictionaryEncoder()
            .encode(encodingParameters)
        
        var urlComponents = URLComponents(
            url: redirectionBaseUrl,
            resolvingAgainstBaseURL: true
        )!
        
        // Map the encoded parameters into
        urlComponents.queryItems = (encodedParameters as! [String: String]).map {
            .init(name: $0.key, value: $0.value)
        }
        
        return urlComponents.url!
    }
    
    /// Parse the redirection link and
    static func create(fromCloudRedirectionLink link: URL) -> NineAnimatorPromise<AnyLink> {
        NineAnimatorPromise.firstly {
            // For parsing the query parameters
            let components = try URLComponents(
                url: link,
                resolvingAgainstBaseURL: true
            ).tryUnwrap()
            
            // Deserialize the parameters from the query into the struct
            let parameters = try DictionaryDecoder().decode(
                SerializedLinkParameters.self,
                from: Dictionary(
                    uniqueKeysWithValues: (components.queryItems ?? []).map {
                        ($0.name, $0.value ?? "")
                    }
                ) as [String: Any]
            )
            
            switch parameters.type {
            case "anime", "episode":
                let animeLink = AnimeLink(
                    title: parameters.title,
                    link: try URL(string: parameters.link).tryUnwrap(),
                    image: try {
                        if let artworkUrlString = parameters.artwork {
                            return try URL(string: artworkUrlString).tryUnwrap()
                        } else { return NineAnimator.placeholderArtworkUrl }
                    }(),
                    source: try NineAnimator
                        .default
                        .source(with: parameters.source)
                        .tryUnwrap(.urlError)
                )
                
                // For the extra parameters used in EpisodeLink
                if parameters.type == "episode" {
                    return .episode(EpisodeLink(
                        identifier: try parameters.identifier.tryUnwrap(),
                        name: try parameters.episode.tryUnwrap(),
                        server: try parameters.server.tryUnwrap(),
                        parent: animeLink
                    ))
                } else { return .anime(animeLink) }
            case "reference":
                // Opening a reference url is not yet supported
                throw NineAnimatorError.unknownError
            default: throw NineAnimatorError.urlError
            }
        }
    }
}

/// A helper class for serializing/deserializing the
/// parameters of the links
private struct SerializedLinkParameters: Codable {
    var type: String
    var title: String
    var source: String
    var link: String
    
    var artwork: String?
    var identifier: String?
    var episode: String?
    var server: String?
    
    init(fromEpisodeLink link: EpisodeLink) {
        self.type = "episode"
        
        // Common to anime link
        self.source = link.parent.source.name
        self.link = link.parent.link.absoluteString
        self.artwork = link.parent.image.absoluteString
        self.title = link.parent.title
        
        // Specific to episode links
        self.episode = link.name
        self.identifier = link.identifier
        self.server = link.server
    }
    
    init(fromAnimeLink link: AnimeLink) {
        self.type = "anime"
        self.source = link.source.name
        self.link = link.link.absoluteString
        self.artwork = link.image.absoluteString
        self.title = link.title
    }
    
    init(fromReference reference: ListingAnimeReference) {
        self.type = "reference"
        self.source = reference.parentService.name
        self.identifier = reference.uniqueIdentifier
        self.artwork = reference.artwork?.absoluteString
        self.title = reference.name
        self.link = "unknown"
    }
}
