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

@objc(NACoreDataListingReference)
public class NACoreDataListingReference: NACoreDataAnyLink {
    public var nativeListingReference: ListingAnimeReference? {
        guard let name = self.name,
            let identifier = self.identifier,
            let stateRaw = self.state,
            let serviceName = self.serviceName else {
            Log.error("[NACoreDataListingReference] Potential data corruption: missing one or more attributes.")
            return nil
        }
        
        guard let parentService = NineAnimator.default.service(with: serviceName) else {
            Log.error("[NACoreDataListingReference] Unknown list service '%@'. Is the app outdated?", serviceName)
            return nil
        }
        
        return ListingAnimeReference(
            parentService,
            name: name,
            identifier: identifier,
            state: ListingAnimeTrackingState(rawValue: stateRaw)
        )
    }
    
    public convenience init(initialListReference listReference: ListingAnimeReference, context: NSManagedObjectContext) {
        self.init(context: context)
        self.identifier = listReference.uniqueIdentifier
        self.serviceName = listReference.parentService.name
        self.state = listReference.state?.rawValue
    }
}
