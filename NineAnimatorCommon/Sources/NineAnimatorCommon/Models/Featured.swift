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

public protocol FeaturedContainer {
    var featured: [AnimeLink] { get }
    
    var latest: [AnimeLink] { get }
}

/// A simple static featured container
public struct BasicFeaturedContainer: FeaturedContainer {
    // The featured anime links
    public var featured: [AnimeLink]
    
    // Links to the latest (last updated) anime on this server
    public var latest: [AnimeLink]
    
    public init(featured: [AnimeLink], latest: [AnimeLink]) {
        self.featured = featured
        self.latest = latest
    }
}
