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

struct NAMasterAnimeStreamingInfo {
    let identifier: Int
    let hostIdentifier: Int
    let hostName: String
    let quality: Int
    
    let embeddedIdentifier: String
    let embeddedPrefix: String
    let embeddedSuffix: String
    
    let locallyHostedUrl: URL?
    
    var target: URL? {
        if let url = locallyHostedUrl { return url }
        return URL(string: "\(embeddedPrefix)\(embeddedIdentifier)\(embeddedSuffix)")
    }
}

struct NAMasterAnimeEpisodeInfo {
    enum SelectOption {
        case firstOccurance
        case bestQuality
        case worstQuality
    }
    
    var link: EpisodeLink
    var url: URL
    var animeIdentifier: String
    var episodeIdentifier: String
    var servers: [NAMasterAnimeStreamingInfo]
    
    var availableHosts: [Anime.ServerIdentifier: String] {
        Dictionary(
            servers.map { ($0.hostName, $0.hostName) }
        ) { oldValue, _ in oldValue }
    }
    
    func select(server hostIdentifier: Anime.ServerIdentifier, option: SelectOption) -> NAMasterAnimeStreamingInfo? {
        var sorted: [NAMasterAnimeStreamingInfo] {
            servers
                .filter { $0.hostName == hostIdentifier }
                .sorted { $0.quality > $1.quality }
        }
        switch option {
        case .bestQuality:
            return sorted.first
        case .worstQuality:
            return sorted.last
        case .firstOccurance:
            return servers.first { $0.hostName == hostIdentifier }
        }
    }
    
    init(_ link: EpisodeLink, streamingInfo: [NSDictionary], with url: URL, parentId: String, episodeId: String) {
        self.link = link
        self.url = url
        self.animeIdentifier = parentId
        self.episodeIdentifier = episodeId
        self.servers = streamingInfo.map {
            source in
            let host = source["host"] as! NSDictionary
            return NAMasterAnimeStreamingInfo(
                identifier: source["id"] as! Int,
                hostIdentifier: source["host_id"] as! Int,
                hostName: host["name"] as! String,
                quality: source["quality"] as! Int,
                embeddedIdentifier: source["embed_id"] as! String,
                embeddedPrefix: host["embed_prefix"] as! String,
                embeddedSuffix: host["embed_suffix"] as? String ?? "",
                locallyHostedUrl: nil
            )
        }
    }
    
    init(_ link: EpisodeLink, locallyHosted videoSources: [(resolution: Int, source: URL)], with url: URL, parentId: String, episodeId: String) {
        self.link = link
        self.url = url
        self.animeIdentifier = parentId
        self.episodeIdentifier = episodeId
        
        self.servers = videoSources.map {
            NAMasterAnimeStreamingInfo(
                identifier: 0,
                hostIdentifier: 0,
                hostName: "masterani.me",
                quality: $0.0,
                embeddedIdentifier: "masterani.me",
                embeddedPrefix: "",
                embeddedSuffix: "",
                locallyHostedUrl: $0.1
            )
        }
    }
}
