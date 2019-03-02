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

import UIKit

class ListingCollectionEntryTableViewCell: UITableViewCell {
    var collection: ListingAnimeCollection? {
        didSet {
            guard let collection = collection else { return }
            
            // If more than one services are providing collections, list
            // each entry with the name of the service
            if NineAnimator
                .default
                .trackingServices
                .filter({ $0.isCapableOfRetrievingAnimeState })
                .count > 1 {
                textLabel?.text = "\(collection.parentService.name) - \(collection.title)"
            } else { textLabel?.text = collection.title }
        }
    }
}
