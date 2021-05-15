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

public protocol ContentProviderDelegate: AnyObject {
    // Index of the page (starting from zero)
    func pageIncoming(_: Int, from provider: ContentProvider)
    
    func onError(_: Error, from provider: ContentProvider)
}

/// An object that provides a list of links
///
/// Content providers should not begin collecting anime until
/// the more() method is called.
public protocol ContentProvider {
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
public protocol AttributedContentProvider: ContentProvider {
    /// Retrieve the attributes
    func attributes(for link: AnyLink, index: Int, on page: Int) -> ContentAttributes?
}

/// A type of content provider that provides release dates
/// of the links
public protocol CalendarProvider: ContentProvider {
    func date(for link: AnyLink, on page: Int) -> Date
}

/// Representing a set of attributes
public class ContentAttributes {
    /// The title that will be used to override the link title
    public var title: String?
    
    /// The subtitle of the entry
    public var subtitle: String?
    
    /// A brief description or synopsis to be presented along with the title
    public var description: String?
    
    public init(title: String? = nil, subtitle: String? = nil, description: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
    }
}

/// A static ContentProvider container
public class StaticContentProvider: ContentProvider {
    public typealias ResultType = Result<[AnyLink], Error>
    
    /// Title of the provider
    public let title: String
    
    /// Contained results
    public let containedResults: ResultType
    
    /// ContentProvider delegate
    public weak var delegate: ContentProviderDelegate?
    
    /// If more contents will be available later
    /// - Note: This property always returns false for StaticContentProvider
    public var moreAvailable: Bool { false }
    
    /// Total page counts. This getter returns `ContentProvider.availablePages`.
    public var totalPages: Int? { availablePages }
    
    /// Available page counts. 1 if the container contains any results (even if empty); 0 otherwise.
    public var availablePages: Int {
        if case .success = self.containedResults {
            return 1
        } else { return 0 }
    }
    
    public func links(on page: Int) -> [AnyLink] {
        page == 0 ? (try? self.containedResults.get()) ?? [] : []
    }
    
    /// Request more contents
    /// - Note: StaticContentProvider calls the delegate method directly whenever more() is called
    public func more() {
        switch self.containedResults {
        case .success:
            delegate?.pageIncoming(0, from: self)
        case let .failure(error):
            delegate?.onError(error, from: self)
        }
    }
    
    /// Initialize the StaticContentProvider with a title string and a result
    public init(title: String, result: ResultType) {
        self.title = title
        self.containedResults = result
    }
}
