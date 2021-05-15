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
import NineAnimatorCommon
import SwiftSoup

extension NASourceAniwatch {
    /*fileprivate struct AnimeEntry: Decodable {
        let airing_end: String
        let airing_start: String
        let cover: String
        let description: String
        let title: String
        let score: String?
    }
    
    fileprivate struct AnimeResponse: Decodable {
        let anime: AnimeEntry
        let success: Bool
    }
    
    fileprivate struct EpisodesResponse: Decodable {
        let episodes: [EpisodeEntry]
        let success: Bool
    }
    
    fileprivate struct EpisodeEntry: Decodable {
        let description: String
        let ep_id: Int
        let title: String
        let number: Int
        let lang: EpisodeLanguages
    }
    
    fileprivate struct EpisodeLanguages: Decodable {
        let desub: Int
        let dedub: Int
        let ensub: Int
        let endub: Int
        let dub: Bool
        let sub: Bool
    }*/
    
    func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
        .fail()
        /*NineAnimatorPromise<String>.firstly {
            // Extract Anime ID From URL
            let animeID = link.link.lastPathComponent
            guard !animeID.isEmpty else { throw NineAnimatorError.urlError }
            return animeID
        } .thenPromise {
            animeID in
            // Request Anime Information
            self.requestManager.request(
                url: self.ajexEndpoint.absoluteString,
                handling: .default,
                method: .post,
                parameters: [
                    "action": "getAnime",
                    "controller": "Anime",
                    "detail_id": animeID
                ],
                encoding: JSONEncoding(),
                headers: [ "x-path": "/anime/\(animeID)" ]
            ).responseDecodable(type: AnimeResponse.self).then { ($0, animeID) }
        } .thenPromise {
            animeResponse, animeID in
            // Request Episode Information
            self.requestManager.request(
                url: self.ajexEndpoint.absoluteString,
                handling: .default,
                method: .post,
                parameters: [
                    "action": "getEpisodes",
                    "controller": "Anime",
                    "detail_id": animeID
                ],
                encoding: JSONEncoding(),
                headers: [ "x-path": "/anime/\(animeID)" ]
            ).responseDecodable(type: EpisodesResponse.self).then {
                (animeResponse, $0)
            }
        } .then {
            animeResponse, episodesResponse in
            let animeCover = try URL(string: animeResponse.anime.cover).tryUnwrap(.urlError)
            
            // Reconstruct AnimeLink
            let newAnimeLink = AnimeLink(
                title: animeResponse.anime.title,
                link: link.link,
                image: animeCover,
                source: self
            )

            let animeDescription = try SwiftSoup.parse(animeResponse.anime.description).text()
            
            // Set Anime Air Date
            var additionalAnimeAttributes = [Anime.AttributeKey: Any]()
            additionalAnimeAttributes[.airDate] = "\(animeResponse.anime.airing_start) to \(animeResponse.anime.airing_end)"
            
            // Set Anime Ratings
            additionalAnimeAttributes[.rating] = Float(animeResponse.anime.score ?? "0")
            additionalAnimeAttributes[.ratingScale] = Float(10)
            
            // Create map of additional episode information
            var episodeInfoMap = [EpisodeLink: Anime.AdditionalEpisodeLinkInformation]()
            // Create EpisodeLink array for each language (aka server)
            var germanSubEpisodes = [EpisodeLink]()
            var germanDubEpisodes = [EpisodeLink]()
            var englishSubEpisodes = [EpisodeLink]()
            var englishDubEpisodes = [EpisodeLink]()
            
            // Returns a episode link and appends additional episode information
            func newEpisode(entry: EpisodeEntry, lang: String, animeLink: AnimeLink) -> EpisodeLink {
                let episodeLink = EpisodeLink(
                    identifier: String(entry.ep_id),
                    name: String(entry.number),
                    server: lang,
                    parent: animeLink
                )
                episodeInfoMap[episodeLink] = Anime.AdditionalEpisodeLinkInformation(
                    parent: episodeLink,
                    synopsis: entry.description,
                    episodeNumber: entry.number,
                    title: entry.title
                )
                return episodeLink
            }
            
            // Add each episode to it's corrisponding server(s)/language(s)
            episodesResponse.episodes.forEach {
                episodeEntry in
                if episodeEntry.lang.desub == 1 {
                    germanSubEpisodes.append(newEpisode(entry: episodeEntry, lang: "desub", animeLink: newAnimeLink))
                }
                if episodeEntry.lang.dedub == 1 {
                    germanDubEpisodes.append(newEpisode(entry: episodeEntry, lang: "dedub", animeLink: newAnimeLink))
                }
                if episodeEntry.lang.ensub == 1 {
                    englishSubEpisodes.append(newEpisode(entry: episodeEntry, lang: "ensub", animeLink: newAnimeLink))
                }
                if episodeEntry.lang.endub == 1 {
                    englishDubEpisodes.append(newEpisode(entry: episodeEntry, lang: "endub", animeLink: newAnimeLink))
                }
            }
            
            // Merge each EpisodeLink array into final Episode Collection
            var episodeCollection = Anime.EpisodesCollection()
            episodeCollection["desub"] = germanSubEpisodes
            episodeCollection["dedub"] = germanDubEpisodes
            episodeCollection["ensub"] = englishSubEpisodes
            episodeCollection["endub"] = englishDubEpisodes
            
            return Anime(
                newAnimeLink,
                alias: "",
                additionalAttributes: additionalAnimeAttributes,
                description: animeDescription,
                on: NASourceAniwatch.knownServers,
                episodes: episodeCollection,
                episodesAttributes: episodeInfoMap
            )
        }*/
    }
}
