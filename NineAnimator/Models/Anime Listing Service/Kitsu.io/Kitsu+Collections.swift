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

extension Kitsu {
    func collections() -> NineAnimatorPromise<[ListingAnimeCollection]> {
        return currentUser().thenPromise {
            [unowned self] in
            self.apiRequest("/library-entries", query: [
                "fields[libraryEntries]": "progress,status,anime",
                "fields[anime]": "canonicalTitle,posterImage",
                "filter[userId]": $0.identifier,
                "filter[kind]": "anime",
                "include": "anime",
                "page[limit]": "20",
                "page[offset]": "0"
            ])
        } .then {
            [unowned self] libraryEntries in
            // First, parse the listing anime reference
            var collections = [String: [ListingAnimeReference]]()
            
            for entry in libraryEntries where entry.type == "libraryEntries" {
                // Only listing anime
                guard let status = entry.attributes["status"] as? String,
                    let relatedAnime = entry.includedRelations["anime"] else { continue }
                
                // Create the reference
                var reference = try ListingAnimeReference(
                    self,
                    withAnimeObject: relatedAnime,
                    libraryEntry: try LibraryEntry(from: entry)
                )
                
                switch status {
                case "completed": reference.state = .finished
                case "current": reference.state = .watching
                case "planned", "on_hold": reference.state = .toWatch
                default: break
                }
                
                // Add the reference to the list
                var list = collections[status] ?? []
                list.append(reference)
                collections[status] = list
            }
            
            return collections.map {
                ListingAnimeCollection(
                    self,
                    name: $0.key.prefix(1).uppercased() + $0.key.lowercased().dropFirst(),
                    identifier: $0.key,
                    collection: $0.value
                )
            }
        }
    }
}
