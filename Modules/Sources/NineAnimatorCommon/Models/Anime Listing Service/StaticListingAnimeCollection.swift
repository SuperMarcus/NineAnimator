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

public struct StaticListingAnimeCollection: ListingAnimeCollection {
    public let parentService: ListingService
    
    /// The "user friendly" name of this collection
    public let title: String
    
    /// Internal identifier of this collection unique to the parent service
    public let identifier: String
    
    /// The list of anime references
    public let collection: [ListingAnimeReference]
    
    public var userInfo: [String: Any]
    
    public init(_ parent: ListingService,
                name: String,
                identifier: String,
                collection: [ListingAnimeReference],
                userInfo: [String: Any] = [:]) {
        self.parentService = parent
        self.title = name
        self.identifier = identifier
        self.collection = collection
        self.userInfo = userInfo
    }
}

public extension StaticListingAnimeCollection {
    var totalPages: Int? { 1 }
    var availablePages: Int { 1 }
    var moreAvailable: Bool { false }
    
    var delegate: ContentProviderDelegate? {
        get { nil }
        set { newValue?.pageIncoming(0, from: self) }
    }
    
    func links(on page: Int) -> [AnyLink] {
        collection.map { .listingReference($0) }
    }
    
    func more() { }
}
