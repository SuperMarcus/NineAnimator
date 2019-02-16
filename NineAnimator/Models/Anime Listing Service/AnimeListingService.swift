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

/// Representing the tracking state of the listed anime
enum ListingAnimeTrackingState {
    case toWatch
    case watching
    case finished
}

/// Representing a listed anime
struct ListingAnimeInformation {
    let parentService: ListingService
}

/// Representing a anime listing service
protocol ListingService {
    /// The name of the listing service
    var name: String { get }
    
    /// Report if this service is capable of generating `ListingAnimeInformation`
    var isCapableOfListingAnimeInformation: Bool { get }
    
    /// Report if this service is capable of receiving notifications about
    /// anime state changes notification (watched, watching, to-watch)
    var isCapableOfPersistingAnimeState: Bool { get }
    
    /// Report if NineAnimator can retrieve anime with states (watched, watching,
    /// to-watch) from this service
    var isCapableOfRetrievingAnimeState: Bool { get }
    
    init(_: NineAnimator)
}
