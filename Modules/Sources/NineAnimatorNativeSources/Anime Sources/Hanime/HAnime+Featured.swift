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
import NineAnimatorCommon

extension NASourceHAnime {
    fileprivate struct Nuxt: Codable {
        let state: State
    }

    fileprivate struct State: Codable {
        let data: DataObject
    }

    fileprivate struct DataObject: Codable {
        let landing: Landing
    }

    fileprivate struct Landing: Codable {
        let processedSections: ProcessedSections
    }

    fileprivate struct ProcessedSections: Codable {
        let recentUploads: [AnimeItems]
        let trending: [AnimeItems]
        
        enum CodingKeys: String, CodingKey {
            case recentUploads = "Recent Uploads"
            case trending = "Trending"
        }
    }

    fileprivate struct AnimeItems: Codable {
        let name: String
        let slug: String
        let coverUrl: String
    }
    
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        self.requestManager.request("/", handling: .browsing).responseString.then {
            responseContent in
            
            guard var serializedAnimeJson = NASourceHAnime
                .animeObjMatchingRegex
                .firstMatch(in: responseContent)?
                .firstMatchingGroup else {
                    throw NineAnimatorError.providerError("Couldn't find NUXT data")
            }

            if serializedAnimeJson.hasSuffix(";") {
                serializedAnimeJson.removeLast()
            }
            
            let jsonData = try serializedAnimeJson.data(using: .utf8)
                    .tryUnwrap(.providerError("Couldn't encode JSON data"))
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let hInfo = try decoder.decode(Nuxt.self, from: jsonData)
            
            let recents = hInfo.state.data.landing.processedSections.recentUploads
            let trending = hInfo.state.data.landing.processedSections.trending
            
            let animeUrl = try URL(string: "/videos/hentai/", relativeTo: self.endpointURL)
                .tryUnwrap(.urlError)
            
            let recentAnime = try recents.map {
                animeContainer -> AnimeLink in
                let artworkString = try self.jetpack(url: animeContainer.coverUrl, quality: 100, cdn: "cps")
                let artworkUrl = try URL(string: artworkString).tryUnwrap(.urlError)
                
                let animeLink = try URL(string: animeContainer.slug, relativeTo: animeUrl)
                        .tryUnwrap(.urlError)
                
                let animeTitle = animeContainer.name
                
                return AnimeLink(
                    title: animeTitle,
                    link: animeLink,
                    image: artworkUrl,
                    source: self
                )
            }
            
            let trendingAnime = try trending.map {
                animeContainer -> AnimeLink in
                let artworkString = try self.jetpack(url: animeContainer.coverUrl, quality: 100, cdn: "cps")
                let artworkUrl = try URL(string: artworkString).tryUnwrap(.urlError)
                
                let animeLink = try URL(string: animeContainer.slug, relativeTo: animeUrl)
                        .tryUnwrap(.urlError)
                
                let animeTitle = animeContainer.name
                
                return AnimeLink(
                    title: animeTitle,
                    link: animeLink,
                    image: artworkUrl,
                    source: self
                )
            }
            
            return BasicFeaturedContainer(featured: trendingAnime, latest: recentAnime)
        }
    }
    
    func jetpack(url: String, quality: Int, cdn: String) throws -> String {
        guard !url.isEmpty else {
            return ""
        }
        
        let tempUrl = try URL(string: url).tryUnwrap(.urlError)
        let realUrl = "\(tempUrl.path)?quality=\(quality)"
        
        if cdn == "cps" {
            let cdns = [
                "https://i1.wp.com/static-assets.airharte.top\(realUrl)",
                "https://i1.wp.com/static-assets.akidoo.top\(realUrl)",
                "https://i1.wp.com/static-assets.mobilius.top\(realUrl)"
            ]
            
            return cdns.randomElement()!
        }
        
        return "https://i1.wp.com/dynamic-assets.imageg.top\(realUrl)"
    }
}
