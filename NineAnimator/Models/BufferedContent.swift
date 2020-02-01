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
import SwiftSoup

protocol ContentProviderDelegate: AnyObject {
    // Index of the page (starting from zero)
    func pageIncoming(_: Int, from provider: ContentProvider)
    
    func onError(_: Error, from provider: ContentProvider)
}

/// An object that provides a list of links
///
/// Content providers should not begin collecting anime until
/// the more() method is called.
protocol ContentProvider {
    var title: String { get }
    
    var totalPages: Int? { get }
    
    var availablePages: Int { get }
    
    var moreAvailable: Bool { get }
    
    var delegate: ContentProviderDelegate? { get set }
    
    func links(on page: Int) -> [AnyLink]
    
    func more()
}

/// A type of content provider that provides additional
/// attributes to each list entry
protocol AttributedContentProvider: ContentProvider {
    /// Retrieve the attributes
    func attributes(for link: AnyLink, index: Int, on page: Int) -> ContentAttributes?
}

/// A type of content provider that provides release dates
/// of the links
protocol CalendarProvider: ContentProvider {
    func date(for link: AnyLink, on page: Int) -> Date
}

/// Representing a set of attributes
class ContentAttributes {
    /// The title that will be used to override the link title
    var title: String?
    
    /// The subtitle of the entry
    var subtitle: String?
    
    /// A brief description or synopsis to be presented along with the title
    var description: String?
    
    init(title: String? = nil, subtitle: String? = nil, description: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
    }
}
