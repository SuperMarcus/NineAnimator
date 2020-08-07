//
//  AnimeHub+Featured.swift
//  NineAnimator
//
//  Created by Uttiya Dutta on 2020-08-07.
//  Copyright © 2020 Marcus Zhou. All rights reserved.
//

import Foundation
import SwiftSoup

extension NASourceAnimeHub {
    func featured() -> NineAnimatorPromise<FeaturedContainer> {
        self.requestManager.request(
            "/animehub.to",
            handling: .browsing
        ).responseString.then {
            responseContent in
            let bowl = try SwiftSoup.parse(responseContent)
            let featuredAnime = try bowl.select("ulclear.grid-item.grid-item-featured")
                .first()
                .tryUnwrap(NineAnimatorError.decodeError("Cannot retrieve featured anime"))
                .select("li")
                .map {
                animeContainer -> AnimeLink in
                
                let animeArtworkURL = try URL(
                    string: animeContainer.select("a.thumb > img").attr("src")
                ) ?? NineAnimator.placeholderArtworkUrl
                
                let animeLink = try URL(
                    string: animeContainer.select("a.thumb").attr("href")
                ).tryUnwrap(NineAnimatorError.urlError)
                
                let animeTitle = try animeContainer.select("a.thumb").attr("title")
                
                return AnimeLink(
                    title: animeTitle,
                    link: animeLink,
                    image: animeArtworkURL,
                    source: self
                )
            }
            
            let ongoingAnime = try bowl.select("ulclear.grid-item.grid-item-featured")[1]
                .select("li")
                .map {
                    animeContainer -> AnimeLink in
                    
                    let animeArtworkURL = try URL(
                        string: animeContainer.select("a.thumb > img").attr("src")
                    ) ?? NineAnimator.placeholderArtworkUrl
                    
                    let animeLink = try URL(
                        string: animeContainer.select("a.thumb").attr("href")
                    ).tryUnwrap(NineAnimatorError.urlError)
                    
                    let animeTitle = try animeContainer.select("a.thumb").attr("title")
                    
                    return AnimeLink(
                        title: animeTitle,
                        link: animeLink,
                        image: animeArtworkURL,
                        source: self
                    )
            }
            
            return BasicFeaturedContainer(
                featured: featuredAnime,
                latest: ongoingAnime
            )
        }
    }
}
