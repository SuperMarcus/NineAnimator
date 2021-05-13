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

public extension Simkl {
    func collections() -> NineAnimatorPromise<[ListingAnimeCollection]> {
        // Check if there is an update to the collections
        return apiRequest(
            "/sync/activities",
            expectedResponseType: [String: Any].self
        ) .then {
            try DictionaryDecoder().decode(SimklActivitiesResponse.self, from: $0)
        } .thenPromise {
            latestActivites -> NineAnimatorPromise<[ListingAnimeCollection]> in
            // If there hasn't been an update
            if let activitiesAnimeEntry = latestActivites.anime?.all,
                let lastAnimeUpdateDate = Simkl.dateFormatter.date(from: activitiesAnimeEntry),
                lastAnimeUpdateDate > self.cachedUserCollectionsLastUpdate {
                Log.info("[Simkl.com] Updates detected, updating cached collections")
                return self.requestUserCollections().then { $0.map { $0.value } }
            } else {
                // Return cached collections list
                Log.info("[Simkl.com] No updates to the collections since last checked. Serving cached collections instead.")
                return .success((self.cachedUserCollections ?? [:]).map { $0.value })
            }
        }
    }
    
    private func requestUserCollections() -> NineAnimatorPromise<[String: Collection]> {
        self.apiRequest(
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
            let dict = Dictionary(uniqueKeysWithValues: collections)
            self.updateCollectionsCache(dict)
            return dict
        }
    }
    
    /// Removes and reset the cache
    func resetCollectionsCache() {
        self.persistedProperties.removeValue(forKey: PersistedKeys.cachedCollections)
        self.cachedUserCollectionsLastUpdate = .distantPast
    }
    
    /// Update the cache for the collections
    func updateCollectionsCache(_ cache: [String: Collection]) {
        self.cachedUserCollections = cache
        self.cachedUserCollectionsLastUpdate = Date()
    }
}

// MARK: - Collection structure
public extension Simkl {
    class Collection: ListingAnimeCollection, Codable {
        private let simkl: Simkl
        private let key: String
        private let references: [ListingAnimeReference]
        private let correspondingState: ListingAnimeTrackingState?
        
        public let title: String
        
        // MARK: Standard interfaces for ListingAnimeCollection
        
        public weak var delegate: ContentProviderDelegate?
        public var parentService: ListingService { simkl }
        public var totalPages: Int? { 1 }
        public var availablePages: Int { 1 }
        public var moreAvailable: Bool { false }
        
        init(_ key: String, title: String, state: ListingAnimeTrackingState?, parent: Simkl, references: [ListingAnimeReference]) {
            self.key = key
            self.simkl = parent
            self.title = title
            self.references = references
            self.correspondingState = state
        }
        
        public func links(on page: Int) -> [AnyLink] {
            page == 0 ? references.map { .listingReference($0) } : []
        }
        
        public func more() { }
        
        // MARK: Implementations for Codable
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Keys.self)
            try container.encode(key, forKey: .key)
            try container.encode(title, forKey: .title)
            try container.encode(references, forKey: .references)
            try container.encodeIfPresent(correspondingState, forKey: .correspondingState)
        }
        
        required public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            self.simkl = NineAnimator.default.service(type: Simkl.self)
            self.key = try container.decode(String.self, forKey: .key)
            self.title = try container.decode(String.self, forKey: .title)
            self.references = try container.decode(
                [ListingAnimeReference].self,
                forKey: .references
            )
            self.correspondingState = try container.decodeIfPresent(
                ListingAnimeTrackingState.self,
                forKey: .correspondingState
            )
        }
        
        private enum Keys: String, CodingKey {
            case key
            case references
            case correspondingState
            case title
        }
    }
}
