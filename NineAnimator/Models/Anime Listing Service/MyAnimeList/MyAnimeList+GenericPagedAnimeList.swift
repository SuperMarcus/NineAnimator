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
    class GenericAnimeList: ContentProvider {
        var title: String
        weak var delegate: ContentProviderDelegate?
        var additionalQueryParameters: [String: CustomStringConvertible]
        var apiPath: String
        
        var moreAvailable: Bool { nextPageOffset != nil }
        var availablePages: Int { loadedPages.count }
        var totalPages: Int? { moreAvailable ? nil : availablePages }
        
        let parent: MyAnimeList
        private(set) var loadedPages = [[ListingAnimeReference]]()
        private(set) var nextPageOffset: Int?
        private var currentFetchTask: NineAnimatorAsyncTask?
        
        func links(on page: Int) -> [AnyLink] {
            loadedPages[page].map { .listingReference($0) }
        }
        
        func more() {
            // Make sure no current fetch task is in progress
            guard currentFetchTask == nil,
                let requestingPage = nextPageOffset else { return }
            
            // Build the parameters
            var parameters = self.additionalQueryParameters
            parameters["limit"] = 5
            parameters["offset"] = requestingPage
            parameters["fields"] = "media_type,num_episodes,my_list_status{start_date,finish_date,num_episodes_watched}"
            
            // Initiate the request
            currentFetchTask = parent.apiRequest(
                    apiPath,
                    query: parameters
                ) .then {
                    [unowned parent, weak self] response -> [(ListingAnimeReference, ListingAnimeTracking?)]? in
                    guard let self = self else { return nil }
                    // Parse the references
                    let references = try response.data.compactMap {
                        $0.valueIfPresent(at: "node", type: NSDictionary.self)
                    } .map {
                        animeNode -> (ListingAnimeReference, ListingAnimeTracking?) in
                        let reference = try ListingAnimeReference(
                            parent,
                            withAnimeNode: animeNode
                        )
                        let tracking = parent.constructTracking(fromAnimeNode: animeNode)
                        return (reference, tracking)
                    }
                    
                    // Save the offset to the next page
                    self.nextPageOffset = response.nextPageOffset
                    
                    return references
                } .error {
                    [weak self] in
                    guard let self = self else { return }
                    self.delegate?.onError($0, from: self)
                    self.currentFetchTask = nil
                } .finally {
                    [weak self, unowned parent] section in
                    guard let self = self else { return }
                    self.loadedPages.append(section.reduce(
                        into: []
                    ) { // Construct the refrence list while donating the tracking to the parent
                        $0.append($1.0)
                        parent.donateTracking($1.1, forReference: $1.0)
                    })
                    self.delegate?.pageIncoming(self.availablePages - 1, from: self)
                    self.currentFetchTask = nil
                }
        }
        
        init(_ path: String, parent: MyAnimeList, title: String, parameters: [String: CustomStringConvertible] = [:]) {
            self.parent = parent
            self.title = title
            self.nextPageOffset = 0
            self.additionalQueryParameters = parameters
            self.apiPath = path
        }
    }
}
