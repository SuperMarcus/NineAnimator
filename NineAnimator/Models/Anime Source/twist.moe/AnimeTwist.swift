//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class NASourceAnimeTwist: BaseSource, Source, PromiseSource {
    var name = "twist.moe"
    
#if canImport(UIKit)
    var siteLogo: UIImage { return #imageLiteral(resourceName: "AnimeTwist Site Icon") }
#elseif canImport(AppKit)
    var siteLogo: NSImage { return #imageLiteral(resourceName: "AnimeTwist Site Icon") }
#endif
    
    var siteDescription: String {
        return "AnimeTwist is a free & ads free anime streaming website. Anime artworks may not be displayed correctly for this website."
    }
    
    override var endpoint: String { return "https://twist.moe" }
    
    fileprivate var _listedAnime: [AnimeTwistListedAnime]?
    
    // swiftlint:disable closure_end_indentation
    var listedAnimePromise: NineAnimatorPromise<[AnimeTwistListedAnime]> {
        if let list = _listedAnime {
            return NineAnimatorPromise<[AnimeTwistListedAnime]> { $0(list, nil); return nil }
        } else {
            return request(browsePath: "/")
                .then {
                    content -> NSDictionary? in
                    guard var serializedAnimeList = self
                        .animeListMatchingRegex
                        .firstMatch(in: content)?
                        .firstMatchingGroup else {
                        throw NineAnimatorError.providerError("No anime found")
                    }
                    // Remove the ';' at the end of the string
                    if serializedAnimeList.hasSuffix(";") {
                        serializedAnimeList.removeLast()
                    }
                    // Parse the anime list object
                    return (try JSONSerialization.jsonObject(
                        with: serializedAnimeList.data(using: .utf8)!,
                        options: []
                    )) as? NSDictionary
                } .then {
                    animeListDictionary -> [AnimeTwistListedAnime]? in
                    guard let _state = animeListDictionary["state"] as? NSDictionary,
                        let _anime = _state["anime"] as? NSDictionary,
                        let allAnimeList = _anime["all"] as? [NSDictionary] else {
                        throw NineAnimatorError.providerError("Unable to decode anime information from list")
                    }
                    return allAnimeList.compactMap {
                        anime in
                        // All required components
                        guard let identifier = anime["id"] as? Int,
                            let title = anime["title"] as? String,
                            let slugContainer = anime["slug"] as? NSDictionary,
                            let slug = slugContainer["slug"] as? String,
                            let onGoingState = anime["ongoing"] as? Int,
                            let createdDateString = anime["created_at"] as? String,
                            let updatedDateString = anime["updated_at"] as? String else {
                            return nil
                        }
                        
                        let alternativeTitle = (anime["alt_title"] as? String) ?? ""
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        
                        // Parse date info from string
                        guard let createdDate = formatter.date(from: createdDateString),
                            let updatedDate = formatter.date(from: updatedDateString) else {
                            return nil
                        }
                        
                        // Construct anime info
                        return AnimeTwistListedAnime(
                            identifier: identifier,
                            title: title,
                            alternativeTitle: alternativeTitle,
                            slug: slug,
                            createdDate: createdDate,
                            updatedDate: updatedDate,
                            isOngoing: onGoingState > 0
                        )
                    }
                } .then {
                    self._listedAnime = $0
                    Log.info("[twist.moe] %@ anime found", $0.count)
                    return $0
                }
        }
    }
    // swiftlint:enable closure_end_indentation
    
    fileprivate let animeListMatchingRegex = try! NSRegularExpression(pattern: "window\\.__NUXT__=([^<]+)", options: [])
    
    override func canHandle(url: URL) -> Bool {
        return false
    }
    
    func reloadAnimeList() -> NineAnimatorPromise<[AnimeTwistListedAnime]> {
        _listedAnime = nil
        return listedAnimePromise
    }
    
    func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
        // Since twist.moe is self hosted, always pass on the decrypted thing
        return VideoProviderRegistry.default.provider(DummyParser.self)
    }
}
