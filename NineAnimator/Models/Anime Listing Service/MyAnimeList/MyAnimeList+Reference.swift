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

extension MyAnimeList {
    func reference(from link: AnimeLink) -> NineAnimatorPromise<ListingAnimeReference> {
        apiRequest("/anime", query: [
            "q": link.title, // Search with the link's title
            "limit": 50,
            "offset": 0,
            "fields": "alternative_titles,media_type,num_episodes,my_list_status{start_date,finish_date,num_episodes_watched}"
        ]) .then {
            response in
            let references: [(proximity: Double, reference: ListingAnimeReference)] = try response.data.compactMap {
                entry in
                guard let animeNode = entry["node"] as? NSDictionary,
                    let alternativeTitles = animeNode["alternative_titles"] as? NSDictionary else {
                    return nil
                }
                
                // Construct the reference
                let reference = try ListingAnimeReference(self, withAnimeNode: animeNode)
                let tracking = self.constructTracking(fromAnimeNode: animeNode)
                self.donateTracking(tracking, forReference: reference)
                
                // Calculate the 'closeness' of title
                var allTitles = [ reference.name ]
                
                if let en = alternativeTitles["en"] as? String {
                    allTitles.append(en)
                }
                
                if let ja = alternativeTitles["ja"] as? String {
                    allTitles.append(ja)
                }
                
                if let synonyms = alternativeTitles["synonyms"] as? [String] {
                    allTitles.append(contentsOf: synonyms)
                }
                
                let proximity = allTitles.reduce(0) {
                    max($0, $1.proximity(to: link.title, caseSensitive: false))
                }
                
                return (proximity, reference)
            }
            guard let bestMatch = references.max(by: { $0.proximity < $1.proximity }) else {
                throw NineAnimatorError.responseError("No matching reference found")
            }
            guard bestMatch.proximity > 0.8 else {
                throw NineAnimatorError.responseError("Failed to make a confident match: maximal proximity is only \(bestMatch.proximity)")
            }
            return bestMatch.reference
        }
    }
}

extension ListingAnimeReference {
    init(_ parent: MyAnimeList, withAnimeNode animeNode: NSDictionary) throws {
        let animeTitle = try some(animeNode["title"] as? String, or: .decodeError)
        let uniqueIdentifier = try some(animeNode["id"] as? Int, or: .decodeError)
        var currentState: ListingAnimeTrackingState?
        let artwork: URL
        
        // Parse the artwork
        if let artworkUrlString = animeNode.valueIfPresent(at: "main_picture.large", type: String.self),
            let artworkUrl = URL(string: artworkUrlString) {
            artwork = artworkUrl
        } else { artwork = NineAnimator.placeholderArtworkUrl }
        
        // If the current status entry is present in the response object
        animeNode.valueIfPresent(
            at: "my_list_status",
            type: NSDictionary.self
        ) .unwrap { // my_list_status: MyListStatusObject
            currentStatusEntry in
            // status: ListStatusEnum
            currentStatusEntry.valueIfPresent(at: "status", type: String.self).unwrap {
                status in
                switch status {
                case "watching": currentState = .watching
                case "plan_to_watch": currentState = .toWatch
                case "completed": currentState = .finished
                default: break
                }
            }
        }
        
        // Call parent initializer
        self.init(
            parent,
            name: animeTitle,
            identifier: String(uniqueIdentifier),
            state: currentState,
            artwork: artwork,
            userInfo: [:]
        )
    }
}
