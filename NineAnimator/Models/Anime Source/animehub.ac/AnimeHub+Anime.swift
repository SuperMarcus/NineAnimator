//
//  AnimeHub+Anime.swift
//  NineAnimator
//
//  Created by Uttiya Dutta on 2020-08-08.
//  Copyright © 2020 Marcus Zhou. All rights reserved.
//

import Foundation
import SwiftSoup

extension NASourceAnimeHub {
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        self.requestManager.request(
            url: link.link,
            handling: .browsing
        ).responseString.then {
            responseContent -> Anime in
            let bowl = try SwiftSoup.parse(responseContent)
            
            let animeTitle = try bowl.select("h1.dc-title").text()
            
            let animeArtworkURL = try URL(
                string: bowl.select("dc-thumb > img").attr("src")
            ) ?? link.image
            
            let reconstructedAnimeLink = AnimeLink(
                title: animeTitle,
                link: link.link,
                image: animeArtworkURL,
                source: self
            )
            
            // Obtain list of episodes
            let episodeList = try bowl.select("#episodes-sv-1 > li").compactMap {
                episodeContainer -> (identifier: String, episodeName: String) in
                let episodeIndentifier = try episodeContainer.select("div.sli-name > a").attr("href")
                
                let episodeName = try episodeContainer.select("div.sli-name > a")
                    .text()
                    .replacingOccurrences(of: "Episode ", with: "")
                return(episodeIndentifier, episodeName)
            }
            
            if episodeList.isEmpty {
                throw NineAnimatorError.responseError("No episodes found for this anime")
            }
            
            // Collection of episodes
            var episodeCollection = Anime.EpisodesCollection()
            
            // We incorrectly assume each server contains every episode
            for (serverIdentifier, _) in NASourceAnimeHub.knownServers {
                var currentCollection = [EpisodeLink]()
                
                for (episodeIdentifier, episodeName) in episodeList {
                    let currentEpisodeLink = EpisodeLink(
                        identifier: episodeIdentifier,
                        name: episodeName,
                        server: serverIdentifier,
                        parent: reconstructedAnimeLink
                    )
                    currentCollection.append(currentEpisodeLink)
                }
                
                episodeCollection[serverIdentifier] = currentCollection.reversed()
            }
            
            // Information
            let animeSynopsis = try bowl.select("div.dci-desc").text()
            
            // Attributes
            var additionalAnimeAttributes = [Anime.AttributeKey: Any]()
            
            let date = try bowl.select("div.dcis.dcis-05")
                .text()
                .replacingOccurrences(of: "Released: ", with: "")
            additionalAnimeAttributes[.airDate] = date
            
            let rating = try bowl.select("#vote_percent").text()
            additionalAnimeAttributes[.rating] = Float(rating) ?? 0
            additionalAnimeAttributes[.ratingScale] = Float(5.0)
            
            return Anime(
                reconstructedAnimeLink,
                alias: "",
                additionalAttributes: additionalAnimeAttributes,
                description: animeSynopsis,
                on: NASourceAnimeHub.knownServers,
                episodes: episodeCollection
            )
        }
    }
}
