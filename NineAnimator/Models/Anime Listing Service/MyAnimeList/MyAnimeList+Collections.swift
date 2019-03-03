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

extension MyAnimeList {
    func collections() -> NineAnimatorPromise<[ListingAnimeCollection]> {
        return .success(_allCollections)
    }
}

extension MyAnimeList {
    class Collection: ListingAnimeCollection {
        private unowned var myAnimeList: MyAnimeList
        
        /// The key of this collection
        private let key: String
        
        weak var delegate: ContentProviderDelegate? { didSet { reset() } }
        
        /// The human readable title of this collection
        var title: String
        
        /// The offset of the next page
        var nextPageOffset: Int?
        
        /// The loaded references
        private var references = [[ListingAnimeReference]]()
        
        /// A reference to the fetch task that the collection is currently performing
        private var currentFetchTask: NineAnimatorAsyncTask?
        
        init(_ parentService: MyAnimeList, key: String, title: String) {
            self.myAnimeList = parentService
            self.title = title
            self.key = key
            self.reset()
        }
    }
}

extension MyAnimeList.Collection {
    /// If there is a next page
    var moreAvailable: Bool { return nextPageOffset != nil }
    
    /// Alias of type erased self.myAnimeList
    var parentService: ListingService { return myAnimeList }
    
    /// Total pages is technically undefined
    var totalPages: Int? {
        return nextPageOffset == nil ? availablePages : nil
    }
    
    /// Return the number of loaded references sections
    var availablePages: Int {
        return references.count
    }
    
    /// Access the refrences in the section
    func links(on page: Int) -> [AnyLink] { return references[page].map { .listingReference($0) } }
}

extension MyAnimeList.Collection {
    /// Remove all cached entries and reset the collection.
    fileprivate func reset() {
        self.nextPageOffset = 0
        self.references = []
    }
    
    func more() {
        // Make sure no current fetch task is in progress
        guard currentFetchTask == nil,
            let requestingPage = nextPageOffset else { return }
        
        Log.info("[MyAnimeList] Requesting page %@ in list %@", requestingPage, title)
        
        // Initiate the request
        currentFetchTask = myAnimeList.apiRequest(
            "/users/@me/animelist",
            query: [
                "status": key,
                "sort": "anime_title",
                "limit": 5,
                "offset": requestingPage,
                "fields": "alternative_titles,media_type,my_list_status{start_date,finish_date}"
            ]
        ) .then {
            [unowned myAnimeList, unowned self] response -> [ListingAnimeReference] in
            // Parse the references
            let references = try response.data.compactMap {
                $0["node"] as? NSDictionary
            } .map { try ListingAnimeReference(myAnimeList, withAnimeNode: $0) }
            
            // Save the offset to the next page
            self.nextPageOffset = response.nextPageOffset
            
            return references
        } .error {
            [unowned self] in
            self.delegate?.onError($0, from: self)
            self.currentFetchTask = nil
        } .finally {
            [unowned self] section in
            self.references.append(section)
            self.delegate?.pageIncoming(self.references.count - 1, from: self)
            self.currentFetchTask = nil
        }
    }
}
