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

extension Simkl {
    struct SimklStdMediaIdentifierEntry: Codable {
        var simkl: Int
    }
    
    struct SimklStdMediaEntry: Codable {
        var title: String
        var ids: SimklStdMediaIdentifierEntry
        var poster: String?
    }
    
    struct SimklLibraryAnimeEntry: Codable {
        var show: SimklStdMediaEntry
        var status: String
    }
    
    struct SimklLibrarySyncResponse: Codable {
        var anime: [SimklLibraryAnimeEntry]
    }
    
    func collections() -> NineAnimatorPromise<[ListingAnimeCollection]> {
        if let cachedCollections = cachedCollections {
            return .success(cachedCollections.map { $0.value })
        }
        return apiRequest(
            "/sync/all-items/anime",
            query: [ "extended": "full" ],
            method: .post,
            expectedResponseType: [String: Any].self
        ) .then {
            try DictionaryDecoder().decode(SimklLibrarySyncResponse.self, from: $0).anime
        } .then {
            libraryAnimeEntries -> [(String, Collection)] in
            var collections = [String: [ListingAnimeReference]]()
            
            for entry in libraryAnimeEntries {
                var refs = collections[entry.status] ?? []
                refs.append(ListingAnimeReference(
                    self,
                    name: entry.show.title,
                    identifier: entry.show.ids.simkl.description,
                    state: self.simklToState(entry.status),
                    artwork: (try? self.artworkUrl(fromPosterPath: entry.show.poster))
                        ?? NineAnimator.placeholderArtworkUrl,
                    userInfo: [:]
                ))
                collections[entry.status] = refs
            }
            
            let namingMaps = [
                "watching": "Watching",
                "plantowatch": "Plan to Watch",
                "hold": "On Hold",
                "completed": "Completed",
                "notinteresting": "Not Interested"
            ]
            
            return collections.map {
                ($0.key, Collection(
                    $0.key,
                    title: namingMaps[$0.key] ?? $0.key,
                    state: self.simklToState($0.key),
                    parent: self,
                    references: $0.value
                ))
            }
        } .then {
            collections in
            self.cachedCollections = Dictionary(uniqueKeysWithValues: collections)
            return collections.map { $0.1 }
        }
    }
    
    func simklToState(_ status: String) -> ListingAnimeTrackingState? {
        switch status {
        case "plantowatch": return .toWatch
        case "watching": return .watching
        case "completed": return .finished
        default: return nil
        }
    }
    
    func stateToSimkl(_ state: ListingAnimeTrackingState) -> String {
        switch state {
        case .toWatch: return "plantowatch"
        case .watching: return "watching"
        case .finished: return "completed"
        }
    }
}

extension Simkl {
    class Collection: ListingAnimeCollection {
        private let simkl: Simkl
        private let key: String
        private let references: [ListingAnimeReference]
        private let correspondingState: ListingAnimeTrackingState?
        
        let title: String
        
        weak var delegate: ContentProviderDelegate?
        var parentService: ListingService { return simkl }
        var totalPages: Int? { return 1 }
        var availablePages: Int { return 1 }
        var moreAvailable: Bool { return false }
        
        init(_ key: String, title: String, state: ListingAnimeTrackingState?, parent: Simkl, references: [ListingAnimeReference]) {
            self.key = key
            self.simkl = parent
            self.title = title
            self.references = references
            self.correspondingState = state
        }
        
        func links(on page: Int) -> [AnyLink] {
            return page == 0 ? references.map { .listingReference($0) } : []
        }
        
        func more() { }
    }
}
