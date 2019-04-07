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
    class KitsuAnimeCollection: ListingAnimeCollection {
        var parentService: ListingService { return parent }
        
        var title: String
        var totalPages: Int?
        var availablePages: Int { return results.count }
        var moreAvailable: Bool { return totalPages == nil }
        weak var delegate: ContentProviderDelegate?
        
        private var identifier: String
        private var results = [[ListingAnimeReference]]()
        private var requestTask: NineAnimatorAsyncTask?
        private var parent: Kitsu
        
        func links(on page: Int) -> [AnyLink] {
            let results = self.results
            guard results.count > page else { return [] }
            return results[page].map { .listingReference($0) }
        }
        
        func more() {
            guard requestTask == nil, moreAvailable else { return }
            let offset = results.reduce(0) { $0 + $1.count }
            let limit = 20
            
            requestTask = parent.currentUser().thenPromise {
                [unowned self] in
                self.parent.apiRequest("/library-entries", query: [
                    "fields[libraryEntries]": "progress,status,anime",
                    "fields[anime]": "canonicalTitle,posterImage",
                    "filter[userId]": $0.identifier,
                    "filter[kind]": "anime",
                    "filter[status]": self.identifier,
                    "include": "anime",
                    "page[limit]": "\(limit)",
                    "page[offset]": "\(offset)"
                ])
            } .then {
                [unowned self] libraryEntries -> [ListingAnimeReference] in
                // First, parse the listing anime reference
                var results = [ListingAnimeReference]()
                var sharedStatus: ListingAnimeTrackingState?
                
                // Get the status
                switch self.identifier {
                case "completed": sharedStatus = .finished
                case "current": sharedStatus = .watching
                case "planned", "on_hold": sharedStatus = .toWatch
                default: break
                }
                
                for entry in libraryEntries where entry.type == "libraryEntries" {
                    // Only listing anime
                    guard let relatedAnime = entry.includedRelations["anime"] else { continue }
                    
                    // Create the reference
                    var reference = try ListingAnimeReference(
                        self.parent,
                        withAnimeObject: relatedAnime,
                        libraryEntry: try LibraryEntry(from: entry)
                    )
                    reference.state = sharedStatus
                    results.append(reference)
                }
                
                return results
            } .error {
                [unowned self] in
                Log.error("errored while getting %@: %@", self.identifier, $0)
                self.delegate?.onError($0, from: self)
                self.requestTask = nil
            } .finally {
                [unowned self] in
                var page = self.results.count
                
                if $0.isEmpty {
                    self.totalPages = page
                    page = max(0, page - 1)
                } else { self.results.append($0) }

                Log.info("%@ references found for list %@", self.results.count, self.identifier)
                self.delegate?.pageIncoming(page, from: self)
                self.requestTask = nil
            }
        }
        
        init (_ statusIdentifier: String, readableStatus: String, parent: Kitsu) {
            self.title = readableStatus
            self.identifier = statusIdentifier
            self.parent = parent
        }
    }
    
    func collections() -> NineAnimatorPromise<[ListingAnimeCollection]> {
        return .success([
            ("dropped", "Dropped"),
            ("completed", "Completed"),
            ("on_hold", "On Hold"),
            ("planned", "To Watch"),
            ("current", "Currently Watching")
        ] .map { KitsuAnimeCollection($0.0, readableStatus: $0.1, parent: self) })
    }
}
