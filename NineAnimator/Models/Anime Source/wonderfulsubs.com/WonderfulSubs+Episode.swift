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

import AVKit
import Foundation

extension NASourceWonderfulSubs {
    struct APIStreamResponse: Codable {
        var status: Int
        var urls: [APIStreamURLEntry]
    }
    
    struct APIStreamURLEntry: Codable {
        var src: String
        var type: String
        var label: String
        var captions: APIStreamCaptionsEntry?
    }
    
    struct APIStreamCaptionsEntry: Codable {
        var src: String
        var srcLang: String
        var label: String
    }
    
    struct APIStreamResponseEmbed: Codable {
        var status: Int
        var embed: String?
        var urls: String?
    }
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        request(
            ajaxPathDictionary: "/api/media/stream",
            query: [ "code": link.identifier ],
            headers: [ "Referer": link.parent.link.absoluteString ]
        ) .then {
            [weak self] response in
            guard let self = self else { return nil }
            
            // A common error for WonderfulSubs
            if response["status"] as? Int == 404 {
                throw NineAnimatorError.responseError("This episode is not available on this server")
            }
            
            do {
                return try self.tryDecodeOrdinary(link, anime: anime, response: response)
            } catch {
                Log.info("[NASourceWonderfulSubs] Unable to decode as ordinary stream response: %@. Trying alternative format.", error)
            }
            
            do {
                return try self.tryDecodeEmbed(link, anime: anime, response: response)
            } catch {
                Log.info("[NASourceWonderfulSubs] Unable to decode as embed stream response: %@.", error)
                throw NineAnimatorError.responseError("This episode cannot be parsed under the current server")
            }
        }
    }
    
    private func tryDecodeEmbed(_ link: EpisodeLink, anime: Anime, response: NSDictionary) throws -> Episode {
        let embedStreamResponse = try DictionaryDecoder().decode(
            APIStreamResponseEmbed.self,
            from: response
        )
        let embedUrl = try URL(string: try (
            embedStreamResponse.embed ?? embedStreamResponse.urls
        ).tryUnwrap()).tryUnwrap()
        return Episode(
            link,
            target: embedUrl,
            parent: anime,
            referer: anime.link.link.absoluteString,
            userInfo: [:]
        )
    }
    
    private func tryDecodeOrdinary(_ link: EpisodeLink, anime: Anime, response: NSDictionary) throws -> Episode {
        // Decode the asset url from the response
        let availableAssets = try DictionaryDecoder().decode(APIStreamResponse.self, from: response)
        let selectedAsset = try availableAssets
            .urls
            .last
            .tryUnwrap(.responseError("NineAnimator does not support the playback of this episode"))
        let targetUrl = try URL(string: selectedAsset.src).tryUnwrap()
        let mediaRetriever: PassthroughParser.MediaRetriever = {
            episode in
            // Disabling CompositionalPlaybackMedia until it has been fixed
            return BasicPlaybackMedia(
                url: targetUrl,
                parent: episode,
                contentType: selectedAsset.type,
                headers: [:],
                isAggregated: DummyParser.registeredInstance!.isAggregatedAsset(mimeType: selectedAsset.type)
            )
            // Assuming that all assets with external subtitles are aggregated, which may not be true
        //                if let captions = selectedAsset.captions {
        //                    return CompositionalPlaybackMedia(
        //                        url: targetUrl,
        //                        parent: episode,
        //                        contentType: selectedAsset.type,
        //                        headers: [:],
        //                        subtitles: [
        //                            (
        //                                url: try URL(string: captions.src).tryUnwrap(),
        //                                name: captions.label,
        //                                language: captions.srcLang
        //                            )
        //                        ]
        //                    )
        //                } else {
        //                    return BasicPlaybackMedia(
        //                        url: targetUrl,
        //                        parent: episode,
        //                        contentType: selectedAsset.type,
        //                        headers: [:],
        //                        isAggregated: DummyParser.registeredInstance!.isAggregatedAsset(mimeType: selectedAsset.type)
        //                    )
        //                }
                    }
                    
                    // Construct the episode object
        return Episode(
            link,
            target: targetUrl,
            parent: anime,
            referer: anime.link.link.absoluteString,
            userInfo: [
                PassthroughParser.Options.playbackMediaRetriever: mediaRetriever,
                "custom.isPassthrough": true
            ]
        )
    }
}
