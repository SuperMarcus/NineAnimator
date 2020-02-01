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

/// An object that can provide recommendations for users
///
/// For how to trigger an update, see `DiscoverySceneViewController`
protocol RecommendationSource: AnyObject {
    typealias Piority = Double
    
    /// The user-friendly name of this recommendation source
    var name: String { get }
    
    /// The piority of this recommendation collection when sorting
    var piority: Piority { get }
    
    /// Check if the recommendation should be reloaded
    func shouldReload(recommendation: Recommendation) -> Bool
    
    /// Retrieve the list of recommendations from this source
    func generateRecommendations() -> NineAnimatorPromise<Recommendation>
}

/// Representing a recommended item
struct RecommendingItem {
    enum CaptionStyle {
        case standard
        case highlight
    }
    
    /// The link to the recommended item
    var link: AnyLink
    
    /// A title of this recommended item
    var title: String
    
    /// A subtitle of this recommended item
    var subtitle: String
    
    /// A text caption displayed on top of the artwork
    var caption: String
    
    /// The preferred style of the caption
    var captionStyle: CaptionStyle
    
    /// A synopsis of the recommended item or the reason that this item is being recommended
    var synopsis: String
    
    /// An artwork of this recommended item
    var artwork: URL
    
    /// Default initializer for the RecommendingItem structure
    ///
    /// Title and artwork is provided by the AnyLink object if not
    /// specified in the parameter list
    init(_ link: AnyLink, title: String = "", caption: String = "", captionStyle: CaptionStyle = .standard, subtitle: String = "", synopsis: String = "", artwork: URL? = nil) {
        self.link = link
        self.title = title.isEmpty ? link.name : title
        self.subtitle = subtitle
        self.synopsis = synopsis
        self.artwork = artwork ?? link.artwork ?? NineAnimator.placeholderArtworkUrl
        self.caption = caption
        self.captionStyle = captionStyle
    }
}

/// A collection of recommendation items
struct Recommendation {
    /// The suggested presentation style of this recommendation collection
    enum Style {
        case thisWeek
        case highlights
        case standard
        case wide
    }
    
    /// The source of this recommendation
    var source: RecommendationSource
    
    /// The recommended items that are contained in this recommendation collection
    var items: [RecommendingItem]
    
    /// The title of this collection
    var title: String
    
    /// The subtitle of this collection
    var subtitle: String
    
    /// The presentation style of this collection of recommendations
    var style: Style
    
    /// An optional content provider for the complete list of recommendation items
    var completeItemListProvider: () -> ContentProvider?
    
    /// The default constructor for generating a Recommendation object
    init(_ source: RecommendationSource,
         items: [RecommendingItem],
         title: String,
         subtitle: String = "",
         style: Style = .standard,
         onGenerateCompleteListProvider: @escaping () -> ContentProvider? = { nil }) {
        self.source = source
        self.items = items
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.completeItemListProvider = onGenerateCompleteListProvider
    }
}

// Some default piority levels
extension RecommendationSource.Piority {
    static let defaultAbsolute: RecommendationSource.Piority = 1000
    
    static let defaultHigh: RecommendationSource.Piority = 750
    
    static let defaultMedium: RecommendationSource.Piority = 500
    
    static let defaultLow: RecommendationSource.Piority = 250
}

extension RecommendationSource {
    /// Notify the observers that the contents in this recommendation
    /// source has been updated
    func fireDidUpdateNotification() {
        NotificationCenter.default.post(name: .sourceDidUpdateRecommendation, object: self)
    }
}
