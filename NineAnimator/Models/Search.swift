//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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
import SwiftSoup

protocol SearchProviderDelegate: AnyObject {
    //Index of the page (starting from zero)
    func pageIncoming(_: Int, from page: SearchProvider)
    
    func noResult(from page: SearchProvider)
}

protocol SearchProvider {
    var query: String { get }
    
    var totalPages: Int? { get }
    
    var availablePages: Int { get }
    
    var moreAvailable: Bool { get }
    
    var delegate: SearchProviderDelegate? { get set }
    
    func animes(on page: Int) -> [AnimeLink]
    
    func more()
}
