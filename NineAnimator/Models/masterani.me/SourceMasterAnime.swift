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

// ---- TO BE FIXED ----
// swiftlint:disable type_body_length
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable function_parameter_count
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
                watchedAnimes.append(AnimeLink(
                    title: title,
                    link: self.anime(slug: slug),
                    image: self.poster(file: posterName),
                    source: self
                ))
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
        return anime(from: link.link, handler)
    }
    
    func anime(from url: URL, _ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask? {
        let animeLinkString = url.absoluteString
        let matches = NASourceMasterAnime.animeResourceIdentifierRegex.matches(in: animeLinkString, range: animeLinkString.matchingRange)
        guard let match = matches.first else {
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        let identifier = animeLinkString[match.range(at: 1)]
        let path = String(format: NASourceMasterAnime.apiPathAnimeDetailed, identifier)
        let task = NineAnimatorMultistepAsyncTask()
        
        Log.info("Requesting episodes of anime %@ on masterani.me", identifier)
        
        task.add(request(ajax: path) { [weak task] response, error in
            guard let task = task else { return }
            guard let response = response else {
                return handler(nil, error)
            }
            func handleError(_ error: String) {
                handler(nil, NineAnimatorError.responseError(error))
            }
            guard let animeInfo = response["info"] as? [String: Any] else {
                return handleError("no info entry found")
            }
            guard let animeSynopsis = animeInfo["synopsis"] as? String else {
                return handleError("no info.synopsis entry found")
            }
            guard let animeTitle = animeInfo["title"] as? String else {
                return handleError("no info.title entry found")
            }
            guard let slug = animeInfo["slug"] as? String else {
                return handleError("no info.slug entry found")
            }
            guard let posterFileName = response["poster"] as? String else {
                return handleError("no poster entry found")
            }
            guard let animeEpisodes = response["episodes"] as? [NSDictionary] else {
                return handleError("no episodes entry found")
            }
            
            let additionalAttributes: [Anime.AttributeKey: Any] = {
                var dict = [Anime.AttributeKey: Any]()
                
                dict[.airDate] = "\(animeInfo["started_airing_date"] as? String ?? "?") - \(animeInfo["finished_airing_date"] as? String ?? "?")"
                
                if let score = animeInfo["score"] as? Double {
                    dict[.rating] = Float(score)
                    dict[.ratingScale] = Float(5.0)
                }
                
                return dict
            }()
            
            let synonyms = ((response["synonyms"] as? [Any]) ?? []).compactMap {
                ($0 as? NSDictionary)?.value(forKey: "title") as? String
            }.joined(separator: "; ")
            
            let parentLink = AnimeLink(
                title: animeTitle,
                link: self.anime(slug: slug),
                image: self.poster(file: posterFileName),
                source: self
            )
            
            let episodes = self.episodes(from: animeEpisodes, with: parentLink)
            
            guard let firstEpisode = episodes.first else {
                return handleError("no episodes found")
            }
            
            Log.debug("Found %@ episodes", episodes.count)
            Log.debug("Requesting availble streaming servers")
            
            task.add(self.assembleAnime(
                withFirstEpisodeLink: firstEpisode.parent,
                parent: parentLink,
                synopsis: animeSynopsis,
                synonyms: synonyms,
                episodes: episodes,
                
                attributes: additionalAttributes,
                handler
            ))
        })
        return task
    }
    
    // Parse the episodes available from the response json object
    private func episodes(from animeEpisodes: [NSDictionary], with parentLink: AnimeLink) -> [Anime.AdditionalEpisodeLinkInformation] {
        return animeEpisodes.compactMap { episode in
            guard let episodeInfo = episode["info"] as? NSDictionary,
                // let episodeIdentifier = episodeInfo["id"] as? Int,
                let episodeNumber = episodeInfo["episode"] as? String,
                let animeIdentifier = episodeInfo["anime_id"] as? Int
                else { return nil }
            
            var episodeName = "\(episodeNumber)"
            // New anime may not always have the title set
            if let episodeTitle = episodeInfo["title"] as? String {
                episodeName = "\(episodeName) - \(episodeTitle)"
            }
            let episode = EpisodeLink(
                identifier: "\(animeIdentifier):\(episodeNumber)",
                name: episodeName,
                server: "Masterani.me",
                parent: parentLink
            )
            return Anime.AdditionalEpisodeLinkInformation(
                parent: episode,
                synopsis: episodeInfo["description"] as? String,
                airDate: episodeInfo["aired"] as? String,
                episodeNumber: Int(episodeNumber),
                title: episodeInfo["title"] as? String
            )
        }
    }
    
    // Assemble Anime object from the first episode link given
    private func assembleAnime(withFirstEpisodeLink link: EpisodeLink,
                               parent parentLink: AnimeLink,
                               synopsis: String,
                               synonyms: String,
                               episodes: [Anime.AdditionalEpisodeLinkInformation],
                               attributes: [Anime.AttributeKey: Any],
                               _ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask? {
        return self.episodeInfo(from: link) { info, error in
            guard let hosts = info?.availableHosts
                else { return handler(nil, error) }
            handler(Anime(
                parentLink,
                alias: synonyms,
                additionalAttributes: attributes,
                description: synopsis,
                on: hosts,
                episodes: Dictionary(uniqueKeysWithValues: hosts.map {
                    host in (
                        host.key,
                        episodes.map { EpisodeLink(
                            identifier: $0.parent.identifier,
                            name: $0.parent.name,
                            server: host.key,
                            parent: $0.parent.parent)
                        }
                    )
                }),
                episodesAttributes: Dictionary(uniqueKeysWithValues: episodes.map { ($0.parent, $0) })
            ), nil)
        }
    }
    
    //Fetch episode mirrors from link
    private func episodeInfo(from link: EpisodeLink, _ handler: @escaping NineAnimatorCallback<NAMasterAnimeEpisodeInfo>) -> NineAnimatorAsyncTask? {
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
            
            guard let bowl = try? SwiftSoup.parse(response) else {
                return handler(nil, NineAnimatorError.responseError("Response is invalid"))
            }
            
            do {
                let mirrors$ = try bowl.select("video-mirrors")
                let mirrorsJsonString = try mirrors$.attr(":mirrors")
                let mirrorsJsonData = mirrorsJsonString.data(using: .utf8)!
                guard let mirrors = try JSONSerialization
                    .jsonObject(with: mirrorsJsonData) as? [NSDictionary] else {
                    throw NineAnimatorError.responseError("invalid mirrors")
                }
                
                Log.debug("%@ mirrors found for episode %@", mirrors.count, episodeNumber)
                
                return handler(NAMasterAnimeEpisodeInfo(
                    link,
                    streamingInfo: mirrors,
                    with: URL(string: "\(endpoint)\(path)")!,
                    parentId: String(animeIdNumber),
                    episodeId: String(episodeNumber)
                ), nil)
            } catch {
                Log.debug("It seems like this episode does not have multiple streaming services.")
                Log.debug("Trying to find a masterani.me hosted video source.")
            }
            
            do {
                let videoSourcesRegex = try NSRegularExpression(pattern: "var\\s*videos\\s*=\\s*(\\[[^\\]]+\\])", options: [.caseInsensitive])
                
                guard let sourceMatch = videoSourcesRegex.matches(in: response, options: [], range: response.matchingRange).first else {
                    throw NineAnimatorError.responseError("No video source found.")
                }
                
                guard let sourceJsonData = response[sourceMatch.range(at: 1)].data(using: .utf8) else {
                    throw NineAnimatorError.responseError("Response cannot be utf8 encoded.")
                }
                
                guard let sourceArray = try JSONSerialization.jsonObject(with: sourceJsonData, options: []) as? NSArray else {
                    throw NineAnimatorError.responseError("Matched object is not an valid JSON array.")
                }
                
                let sources = sourceArray.compactMap { source -> (resolution: Int, source: URL, type: String)? in
                    guard let source = source as? NSDictionary else {
                        Log.error("One of the source object cannot be cast to NSDictionary")
                        return nil
                    }
                    
                    guard let res = source["res"] as? Int,
                          let srcString = source["src"] as? String,
                          let src = URL(string: srcString),
                          let type = source["type"] as? String else {
                        Log.error("Values are incomplete for one of the objects in this episode")
                        return nil
                    }
                    
                    return (res, src, type)
                }
                
                handler(NAMasterAnimeEpisodeInfo(
                    link,
                    locallyHosted: sources.map { ($0.0, $0.1) },
                    with: URL(string: "\(endpoint)\(path)")!,
                    parentId: String(animeIdNumber),
                    episodeId: String(episodeNumber)
                ), nil)
            } catch {
                Log.error("Did not find a masterani.me hosted video source either (%@). Aborting.", error)
                handler(nil, error)
            }
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
    
    func search(keyword: String) -> ContentProvider {
        Log.info("Searching masterani.me with keyword '%@'", keyword)
        return NASearchMasterAnime(query: keyword, parent: self)
    }
    
    func poster(file name: String) -> URL {
        return URL(string: "\(NASourceMasterAnime.cdnEndpoint)/poster/1/\(name)")!
    }
    
    func anime(slug: String) -> URL {
        return URL(string: "\(endpoint)\(NASourceMasterAnime.animePathInfo)\(slug)")!
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        if name == "masterani.me" {
            return VideoProviderRegistry.default.provider(DummyParser.self)
        }
        return VideoProviderRegistry.default.provider(for: name)
    }
}
