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

import CoreData
import Foundation

public extension NACoreDataLibrary {
    class Context {
        fileprivate let _coreDataContext: NSManagedObjectContext
        
        internal init(withContext context: NSManagedObjectContext) {
            self._coreDataContext = context
        }
    }
}

// MARK: - Recents
public extension NACoreDataLibrary.Context {
    /// Obtain the list of recently viewed titles
    func fetchRecents() throws -> [AnyLink] {
        try _coreDataContext.performWithResults {
            try _coreDataContext
                .fetch(_recentsFetchRequest())
                .compactMap {
                    $0.link?.nativeAnyLink
                }
        }
    }
    
    /// Obtain a fetch results controller for the recent records
    func fetchRecentsController() -> NSFetchedResultsController<NACoreDataLibraryRecord> {
        let request = _recentsFetchRequest()
        return NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: _coreDataContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }
    
    /// Remove a single entry from the library
    func removeLibraryRecord(record: NACoreDataLibraryRecord) throws {
        _coreDataContext.delete(record)
        try _coreDataContext.save()
    }
    
    /// Update the recently accessed record for the link
    func updateLibraryRecord(forLink link: AnyLink) throws {
        let record = try _obtainManagedRecord(forAnyLink: link)
        // Update metadata for the link
        // This is important in cases such as where Anime Sources may have initially
        // provided incorrect data (ex. parsed a broken artworkURL), but later provides
        // correct information (ex. user has updated the app to fix parser)
        if let artworkURL = link.artwork {
            record.link?.artwork = artworkURL
        }
        record.link?.name = link.name
        record.lastAccess = Date()
        try _coreDataContext.save()
    }
    
    /// Reset the recently viewed titles to the array of AnyLink.
    ///
    /// This is a time-consuming operation and should not be performed regularly. This operation also erases any information about the individual records.
    func resetRecents(to newRecents: [AnyLink] = []) throws {
        try _coreDataContext.performWithResults {
            // First remove all library records
            let recentsFetchRequest = NACoreDataLibraryRecord.fetchRequest() as NSFetchRequest<NSFetchRequestResult>
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: recentsFetchRequest)
            _ = try self._coreDataContext.execute(deleteRequest)
            
            var dummyUpdateDate = Date()
            for recent in newRecents {
                let managedRecord = try _obtainManagedRecord(forAnyLink: recent)
                managedRecord.lastAccess = dummyUpdateDate
                dummyUpdateDate = dummyUpdateDate.addingTimeInterval(-1)
            }
            
            try _coreDataContext.save()
        }
    }
}

// MARK: - Private Helpers
internal extension NACoreDataLibrary.Context {
    fileprivate func _obtainManagedRecord(forAnyLink anyLink: AnyLink) throws -> NACoreDataLibraryRecord {
        let request = NACoreDataLibraryRecord.fetchRequest() as NSFetchRequest<NACoreDataLibraryRecord>
        let managedLink = try _obtainManagedLink(forAnyLink: anyLink)
        request.predicate = NSPredicate(
            format: "link == %@",
            managedLink
        )
        request.fetchLimit = 1
        
        if let existingRecord = try _coreDataContext.fetch(request).first {
            return existingRecord
        }
        
        return NACoreDataLibraryRecord(
            associatedLink: managedLink,
            context: _coreDataContext
        )
    }
    
    fileprivate func _obtainManagedLink(forAnyLink anyLink: AnyLink) throws -> NACoreDataAnyLink {
        switch anyLink {
        case let .anime(animeLink):
            return try _obtainManagedAnimeLink(animeLink)
        case let .listingReference(reference):
            return try _obtainManagedListReference(reference)
        case .episode:
            throw NineAnimatorError.unknownError("Episode links passed into _obtainManagedLink")
        }
    }
    
    fileprivate func _obtainManagedAnimeLink(_ animeLink: AnimeLink) throws -> NACoreDataAnimeLink {
        let request = NACoreDataAnimeLink.fetchRequest() as NSFetchRequest<NACoreDataAnimeLink>
        request.predicate = NSPredicate(format: "url = %@", animeLink.link as NSURL)
        request.fetchLimit = 1
        
        if let existingRecord = try _coreDataContext.fetch(request).first {
            return existingRecord
        }
        
        return NACoreDataAnimeLink(
            initialAnimeLink: animeLink,
            context: _coreDataContext
        )
    }
    
    fileprivate func _obtainManagedListReference(_ listingReference: ListingAnimeReference) throws -> NACoreDataListingReference {
        let request = NACoreDataListingReference.fetchRequest() as NSFetchRequest<NACoreDataListingReference>
        request.predicate = NSPredicate(
            format: "(serviceName == %@) AND (identifier == %@)",
            listingReference.parentService.name,
            listingReference.uniqueIdentifier
        )
        request.fetchLimit = 1
        
        if let existingRecord = try _coreDataContext.fetch(request).first {
            return existingRecord
        }
        
        return NACoreDataListingReference(
            initialListReference: listingReference,
            context: _coreDataContext
        )
    }
    
    /// Obtain a NSFetchRequest for a list of library records sorted by lastAccess
    fileprivate func _recentsFetchRequest() -> NSFetchRequest<NACoreDataLibraryRecord> {
        let request = NACoreDataLibraryRecord.fetchRequest() as NSFetchRequest<NACoreDataLibraryRecord>
        request.sortDescriptors = [
            .init(key: "lastAccess", ascending: false)
        ]
        request.relationshipKeyPathsForPrefetching = [
            "link"
        ]
        return request
    }
}
