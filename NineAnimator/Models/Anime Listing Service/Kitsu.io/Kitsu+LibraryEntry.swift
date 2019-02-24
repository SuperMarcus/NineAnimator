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
    struct LibraryEntry: Codable {
        let identifier: String
        let progress: Int
        let status: String
        
        init(from libraryEntry: APIObject) throws {
            guard libraryEntry.type == "libraryEntries" else {
                throw NineAnimatorError.responseError("An non-\"libraryEntries\" typed object was passed to the constructor of LibraryEntry")
            }
            
            // Construct the LibraryEntry with the provided elements
            identifier = libraryEntry.identifier
            progress = try libraryEntry.attributes.value(at: "progress", type: Int.self)
            status = try libraryEntry.attributes.value(at: "status", type: String.self)
        }
    }
    
    func libraryEntry(with animeIdentifier: String) -> NineAnimatorPromise<LibraryEntry> {
        return currentUser().thenPromise {
            [unowned self] user in
            self.apiRequest("/library-entries", query: [
                "filter[animeId]": animeIdentifier,
                "filter[userId]": user.identifier,
                "fields[libraryEntries]": "progress,status"
            ])
        } .then {
            response in
            guard let entry = response.first else {
                throw NineAnimatorError.responseError("The library entry of this anime does not exists")
            }
            return try LibraryEntry(from: entry)
        }
    }
    
    func libraryEntry(for reference: ListingAnimeReference) -> NineAnimatorPromise<LibraryEntry> {
        if let entry = reference.userInfo["libraryEntry"] as? LibraryEntry {
            return .firstly { entry }
        }
        
        return libraryEntry(with: reference.uniqueIdentifier)
    }
}
