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
import JavaScriptCore

@available(iOS 13, *)
@objc protocol NACoreEngineExportsAnimeProtocol: JSExport {
    typealias ExportServerIdentifier = Anime.ServerIdentifier
    typealias ExportEpisodeLinksCollection = [NACoreEngineExportsEpisodeLink]
    typealias ExportEpisodesCollection = [ExportServerIdentifier: ExportEpisodeLinksCollection]
    typealias ExportAttributeCollection = [Anime.AttributeKey: Any]
    typealias ExportServerNameMap = [ExportServerIdentifier: String]
    
    var link: NACoreEngineExportsAnimeLink { get }
    var servers: ExportServerNameMap { get }
    var episodes: ExportEpisodesCollection { get }
    var description: String { get }
    var alias: String { get }
    var episodeAttributes: [NACoreEngineExportsAdditionalEpisodeLinkInformation] { get }
    var additionalAttributes: ExportAttributeCollection { get }
    var children: [NACoreEngineExportsAnime] { get }
    
    func getEpisodesOnServer(_ serverIdentifier: ExportServerIdentifier) -> ExportEpisodeLinksCollection
    func getAttributeForEpisode(_ episodeLink: NACoreEngineExportsEpisodeLink) -> NACoreEngineExportsAdditionalEpisodeLinkInformation?
    func getEpisodeLinkByID(_ episodeIdentifier: String) -> NACoreEngineExportsEpisodeLink?
    func getEpisodeLinksByName(_ episodeName: String) -> [NACoreEngineExportsEpisodeLink]
    
    init?(link: NACoreEngineExportsAnimeLink?,
          alias: String?,
          additionalAttributes: ExportAttributeCollection?,
          description: String?,
          serverFriendlyNames: ExportServerNameMap?,
          episodes: ExportEpisodesCollection?,
          episodesAttributes: [NACoreEngineExportsAdditionalEpisodeLinkInformation]?)
    
    static func createCollectionAnimeObject(
        link: NACoreEngineExportsAnimeLink?,
        alias: String?,
        additionalAttributes: ExportAttributeCollection?,
        description: String?,
        children: [NACoreEngineExportsAnime]?
    ) -> NACoreEngineExportsAnime?
}

@available(iOS 13, *)
@objc class NACoreEngineExportsAnime: NSObject, NACoreEngineExportsAnimeProtocol {
    dynamic var link: NACoreEngineExportsAnimeLink {
        .init(underlyingAnimeObject.link)
    }
    
    dynamic var servers: [ExportServerIdentifier: String] {
        underlyingAnimeObject.servers
    }
    
    dynamic var episodes: ExportEpisodesCollection {
        underlyingAnimeObject.episodes.mapValues {
            episodeList in episodeList.map {
                .init($0)
            }
        }
    }
    
    dynamic var alias: String {
        underlyingAnimeObject.alias
    }
    
    dynamic var episodeAttributes: [NACoreEngineExportsAdditionalEpisodeLinkInformation] {
        underlyingAnimeObject.episodesAttributes.compactMap {
            .init($0.value)
        }
    }
    
    dynamic var additionalAttributes: [Anime.AttributeKey: Any] {
        underlyingAnimeObject.additionalAttributes
    }
    
    dynamic var children: [NACoreEngineExportsAnime] {
        underlyingAnimeObject.children.map {
            .init($0)
        }
    }
    
    let underlyingAnimeObject: Anime
    
    init(_ nativeAnimeObject: Anime) {
        self.underlyingAnimeObject = nativeAnimeObject
    }
    
    required init?(link: NACoreEngineExportsAnimeLink?, alias: String?, additionalAttributes: ExportAttributeCollection?, description: String?, serverFriendlyNames: ExportServerNameMap?, episodes: ExportEpisodesCollection?, episodesAttributes: [NACoreEngineExportsAdditionalEpisodeLinkInformation]?) {
        guard let engine = NACoreEngine.current() else {
            Log.error("[NACoreEngineExportsAnime] Cannot construct NACoreEngineExportsAnime from a native context.")
            return nil
        }
        
        guard let link = link, let convertedAnimeLink = link.nativeAnimeLink else {
            engine.raiseErrorInContext(NineAnimatorError.argumentError("The provided AnimeLink object is either undefined or invalid."))
            return nil
        }
        
        guard let serverFriendlyNames = serverFriendlyNames, !serverFriendlyNames.isEmpty else {
            engine.raiseErrorInContext(NineAnimatorError.argumentError("The provided server name map is either undefined or invalid."))
            return nil
        }
        
        guard let episodes = engine.validateValue(episodes) else {
            engine.raiseErrorInContext(NineAnimatorError.argumentError("The provided episode list is either undefined or invalid."))
            return nil
        }
        
        let convertedServerEpisodeMap = Dictionary(uniqueKeysWithValues: episodes.map {
            episodeListPair in (episodeListPair.key, episodeListPair.value.compactMap {
                $0.nativeEpisodeLink
            })
        })
        
        let convertedEpisodeAttributes = engine.validateValue(episodesAttributes).unwrap {
            Dictionary($0.map {
                ($0.parentLink, $0.nativeAdditionalEpisodeLinkInformation)
            }) { $1 }
        }
        
        self.underlyingAnimeObject = .init(
            convertedAnimeLink,
            alias: alias ?? "",
            additionalAttributes: engine.validateValue(additionalAttributes) ?? [:],
            description: description ?? "No description",
            on: serverFriendlyNames,
            episodes: convertedServerEpisodeMap,
            episodesAttributes: convertedEpisodeAttributes ?? [:]
        )
    }
    
    @objc func getEpisodesOnServer(_ serverIdentifier: ExportServerIdentifier) -> ExportEpisodeLinksCollection {
        underlyingAnimeObject.episodes[serverIdentifier as Anime.ServerIdentifier]?.map {
            .init($0)
        } ?? []
    }
    
    @objc func getAttributeForEpisode(_ episodeLink: NACoreEngineExportsEpisodeLink) -> NACoreEngineExportsAdditionalEpisodeLinkInformation? {
        if let nativeEpisodeLink = episodeLink.nativeEpisodeLink,
           let nativeEpisodeInfo = underlyingAnimeObject.episodesAttributes[nativeEpisodeLink] {
            return .init(nativeEpisodeInfo)
        }
        
        return nil
    }
    
    @objc
    func getEpisodeLinksByName(_ episodeName: String) -> [NACoreEngineExportsEpisodeLink] {
        underlyingAnimeObject.episodes.links(withName: episodeName).map {
            .init($0)
        }
    }
    
    @objc
    func getEpisodeLinkByID(_ episodeIdentifier: String) -> NACoreEngineExportsEpisodeLink? {
        underlyingAnimeObject.episodes.link(withIdentifier: episodeIdentifier).unwrap {
            .init($0)
        }
    }
    
    @objc
    class func createCollectionAnimeObject(link: NACoreEngineExportsAnimeLink?, alias: String?, additionalAttributes: ExportAttributeCollection?, description: String?, children: [NACoreEngineExportsAnime]?) -> NACoreEngineExportsAnime? {
        guard let engine = NACoreEngine.current() else {
            Log.error("[NACoreEngineExportsAnime] Cannot construct a collection NACoreEngineExportsAnime from a native context.")
            return nil
        }
        
        guard let link = link, let convertedAnimeLink = link.nativeAnimeLink else {
            engine.raiseErrorInContext(NineAnimatorError.argumentError("The provided AnimeLink object is either undefined or invalid."))
            return nil
        }
        
        guard let children = engine.validateValue(children) else {
            engine.raiseErrorInContext(NineAnimatorError.argumentError("The provided list of children Anime object is either undefined or invalid."))
            return nil
        }
        
        let convertedChildren = children.map {
            $0.underlyingAnimeObject
        }
        
        let instantiatedAnimeObject = Anime(
            convertedAnimeLink,
            alias: alias ?? "",
            additionalAttributes: engine.validateValue(additionalAttributes) ?? [:],
            description: description ?? "No description",
            children: convertedChildren
        )
        
        return .init(instantiatedAnimeObject)
    }
}
