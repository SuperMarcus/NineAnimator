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

import Foundation
import SwiftSoup

class NASourceMasterAnime: BaseSource, Source {
    var name: String = "masterani.me"
    
    override var endpoint: String { return "https://www.masterani.me" }
    
    static let cdnEndpoint = "https://cdn.masterani.me"
    
    static let apiPathTrending = "/api/anime/trending"
    static let apiPathReleases = "/api/releases"
    static let apiPathAnimeDetailed = "/api/anime/%@/detailed"
    static let animePathInfo = "/anime/info/"
    static let episodePathWatch = "/anime/watch/%@/%@"
    static let episodePathVerify = "/api/user/library/episode/%@?episode=%@&episode_id=%@&trigger=0"
    
    static let animeResourceIdentifierRegex = try! NSRegularExpression(pattern: "\\/(\\d+)[\\da-zA-Z0-9-_]+$", options: .caseInsensitive)
    static let animeCompleteIdentifierRegex = try! NSRegularExpression(pattern: "\\/([\\da-zA-Z0-9-_]+)$", options: .caseInsensitive)
    
    func featured(_ handler: @escaping NineAnimatorCallback<FeaturedContainer>) -> NineAnimatorAsyncTask? {
        return request(ajax: NASourceMasterAnime.apiPathTrending) {
            response, error in
            guard let response = response else {
                return handler(nil, error)
            }
            
            guard let beingWatchedAnimes = response["being_watched"] as? [NSDictionary] else {
                return handler(nil, NineAnimatorError.responseError(
                    "no being watched animes entry found"
                ))
            }
            
            guard let popularAnimes = response["popular_today"] as? [NSDictionary] else {
                return handler(nil, NineAnimatorError.responseError(
                    "no trending animes entry found"
                ))
            }
            
            var watchedAnimes = [AnimeLink]()
            
            for anime in beingWatchedAnimes {
                guard let title = anime["title"] as? String,
                    let slug = anime["slug"] as? String,
                    let posterName = anime["poster"] as? String
                    else { continue }
                let animeLink = AnimeLink(
                    title: title,
                    link: self.anime(slug: slug),
                    image: self.poster(file: posterName),
                    source: self)
                watchedAnimes.append(animeLink)
            }
            
            let alsoFeaturedAnimes: [AnimeLink] =
                popularAnimes.compactMap { anime in
                guard let title = anime["title"] as? String,
                    let slug = anime["slug"] as? String,
                    let posterName = anime["poster"] as? String
                    else { return nil }
                return AnimeLink(
                    title: title,
                    link: self.anime(slug: slug),
                    image: self.poster(file: posterName),
                    source: self
                )
                }
            
            let featuredPage = BasicFeaturedContainer(featured: alsoFeaturedAnimes, latest: watchedAnimes)
            handler(featuredPage, nil)
        }
    }
    
    func anime(from link: AnimeLink, _ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask? {
        let animeLinkString = link.link.absoluteString
        let matches = NASourceMasterAnime.animeResourceIdentifierRegex.matches(in: animeLinkString, options: [], range: animeLinkString.matchingRange)
        guard let match = matches.first else {
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        let identifier = animeLinkString[match.range(at: 1)]
        let path = String(format: NASourceMasterAnime.apiPathAnimeDetailed, identifier)
        let task = NineAnimatorMultistepAsyncTask()
        
        debugPrint("Info: Requesting episodes of anime \(identifier) on masterani.me")
        
        task.add(request(ajax: path) {
            [weak task] response, error in
            guard let task = task else { return }
            guard let response = response else {
                return handler(nil, error)
            }
            
            guard let animeInfo = response["info"] as? [String: Any] else {
                return handler(nil, NineAnimatorError.responseError(
                    "no info entry found"
                ))
            }
            
            guard let animeSynopsis = animeInfo["synopsis"] as? String else {
                return handler(nil, NineAnimatorError.responseError(
                    "no info.synopsis entry found"
                ))
            }
            
            guard let animeEpisodes = response["episodes"] as? [NSDictionary] else {
                return handler(nil, NineAnimatorError.responseError(
                    "no episodes entry found"
                ))
            }
            
            let episodes: [EpisodeLink] = animeEpisodes.compactMap {
                episode in
                guard let episodeInfo = episode["info"] as? NSDictionary,
                    // let episodeIdentifier = episodeInfo["id"] as? Int,
                    let episodeNumber = episodeInfo["episode"] as? String,
                    let animeIdentifier = episodeInfo["anime_id"] as? Int
                    else { return nil }
                
                var episodeName = "\(episodeNumber)"
                
                //New anime may not always have the title set
                if let episodeTitle = episodeInfo["title"] as? String {
                    episodeName = "\(episodeName) - \(episodeTitle)"
                }
                
                return EpisodeLink(
                    identifier: "\(animeIdentifier):\(episodeNumber)",
                    name: episodeName,
                    server: "Masterani.me",
                    parent: link
                )
            }
            
            guard let firstEpisode = episodes.first else {
                return handler(nil, NineAnimatorError.responseError(
                    "no episodes found"
                ))
            }
            
            debugPrint("Info: Found \(episodes.count) episodes")
            debugPrint("Info: Requesting availble streaming servers")
            
            task.add(self.episodeInfo(from: firstEpisode) {
                info, error in
                guard let info = info else { return handler(nil, error) }
                let hosts = info.availableHosts
                handler(Anime(
                    link,
                    description: animeSynopsis,
                    on: hosts,
                    episodes: Dictionary(uniqueKeysWithValues: hosts.map {
                        host in
                        (
                            host.key,
                            episodes.map { EpisodeLink(
                                identifier: $0.identifier,
                                name: $0.name,
                                server: host.key,
                                parent: $0.parent)
                            }
                        )
                    })
                ), nil)
            })
        })
        return task
    }
    
    //Fetch episode mirrors from link
    func episodeInfo(from link: EpisodeLink, _ handler: @escaping NineAnimatorCallback<NAMasterAnimeEpisodeInfo>) -> NineAnimatorAsyncTask? {
        let episodeUniqueId = link.identifier.split(separator: ":")
        guard let episodeNumber = episodeUniqueId.last else {
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        guard let animeIdNumber = episodeUniqueId.first else {
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        let animeLinkString = link.parent.link.absoluteString
        let matches = NASourceMasterAnime.animeCompleteIdentifierRegex.matches(
            in: animeLinkString, options: [], range: animeLinkString.matchingRange
        )
        guard let animeIdentifier = matches.first else {
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        let path = String(
            format: NASourceMasterAnime.episodePathWatch,
            animeLinkString[animeIdentifier.range(at: 1)],
            String(episodeNumber)
        )
        return request(browse: path) {
            [endpoint] response, error in
            guard let response = response else { return handler(nil, error) }
            do {
                let bowl = try SwiftSoup.parse(response)
                let mirrors$ = try bowl.select("video-mirrors")
                let mirrorsJsonString = try mirrors$.attr(":mirrors")
                let mirrorsJsonData = mirrorsJsonString.data(using: .utf8)!
                guard let mirrors = try JSONSerialization
                    .jsonObject(with: mirrorsJsonData) as? [NSDictionary] else {
                    throw NineAnimatorError.responseError("invalid mirrors")
                }
                debugPrint("Info: \(mirrors.count) mirrors found for episode \(episodeNumber)")
                handler(NAMasterAnimeEpisodeInfo(
                    link,
                    streamingInfo: mirrors,
                    with: URL(string: "\(endpoint)\(path)")!,
                    parentId: String(animeIdNumber),
                    episodeId: String(episodeNumber)
                ), nil)
            } catch let e { handler(nil, e) }
        }
    }
    
    func episode(from link: EpisodeLink, with anime: Anime, _ handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask? {
        let task = NineAnimatorMultistepAsyncTask()
        task.add(episodeInfo(from: link) {
            info, error in
            guard let info = info else { return handler(nil, error) }
            guard let stream = info.select(server: link.server, option: .bestQuality) else {
                return handler(nil, NineAnimatorError.providerError(
                    "This episode is not availble on the selected server"
                ))
            }
            
            guard let streamTarget = stream.target else {
                return handler(nil, NineAnimatorError.urlError)
            }
            let episode = Episode(link, target: streamTarget, parent: anime, referer: info.url.absoluteString)
            handler(episode, nil)
        })
        return task
    }
    
    func search(keyword: String) -> SearchPageProvider {
        debugPrint("Info: Searching masterani.me with keyword '\(keyword)'")
        return NASearchMasterAnime(query: keyword, parent: self)
    }
    
    func poster(file name: String) -> URL {
        return URL(string: "\(NASourceMasterAnime.cdnEndpoint)/poster/1/\(name)")!
    }
    
    func anime(slug: String) -> URL {
        return URL(string: "\(endpoint)\(NASourceMasterAnime.animePathInfo)\(slug)")!
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        return VideoProviderRegistry.default.provider(for: name)
    }
}
