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

import CoreSpotlight
import Foundation
import Kingfisher
import UIKit

/// A helper struct that facilitates NineAnimator continuity functions
enum Continuity {
    static let activityTypeViewAnime = "com.marcuszhou.nineanimator.activity.viewAnime"
    
    static let activityTypeContinueEpisode = "com.marcuszhou.nineanimator.activity.continueEpisode"
    
    static let activityTypeResumePlayback = "com.marcuszhou.nineanimator.activity.resumePlayback"
    
    /// Obtain the activity for currently browsing anime
    static func activity(for anime: Anime) -> NSUserActivity {
        let link = anime.link
        let activity = NSUserActivity(activityType: activityTypeViewAnime)
        
        activity.title = "Watch \(link.title)"
        activity.webpageURL = link.link
        activity.keywords = [ link.title, "anime" ]
        
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: "public.movie")
        attributeSet.contentURL = link.link
        attributeSet.displayName = link.title
        attributeSet.keywords = [ link.title, "anime" ]
        attributeSet.thumbnailURL = URL(string: Kingfisher.ImageCache.default.cachePath(forKey: link.image.absoluteString))
        
        if let url = attributeSet.thumbnailURL, let image = UIImage(contentsOfFile: url.absoluteString) {
            attributeSet.thumbnailData = image.jpegData(compressionQuality: 0.8)
        } else { Log.info("Thumbnail cannot be saved to activity now for this anime. Will be saved later if needed.") }
        
        attributeSet.contentSources = [ link.source.name ]
        attributeSet.contentDescription = anime.description
        
        activity.contentAttributeSet = attributeSet
        
        activity.isEligibleForSearch = true
        activity.isEligibleForHandoff = true
        activity.isEligibleForPublicIndexing = true
        activity.needsSave = false
        
        if #available(iOS 12.0, *) {
            activity.isEligibleForPrediction = true
            activity.persistentIdentifier = identifier(for: link.link)
        }
        
        do {
            let encoder = PropertyListEncoder()
            let data = try encoder.encode(link)
            
            activity.userInfo = [ "link": data ]
        } catch { Log.error("Cannot encode AnimeLink into activity (%@). This activity may become invalid.", error) }
        
        return activity
    }
    
    static func activity(for media: PlaybackMedia) -> NSUserActivity {
        let link = media.link
        let activity = NSUserActivity(activityType: activityTypeContinueEpisode)
        
        activity.title = "Continue Watching Episode \(link.name) of \(link.parent.title)"
        activity.webpageURL = link.parent.link // Also using the anime's webpage url since otherwise it would be useless
        activity.keywords = [ media.name, link.parent.title, "anime", "episode" ]
        
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: "public.movie")
        attributeSet.contentURL = link.parent.link
        attributeSet.displayName = "Continue Watching Episode \(link.name)"
        attributeSet.keywords = [ media.name, link.parent.title, "anime", "episode" ]
        attributeSet.thumbnailURL = URL(string: Kingfisher.ImageCache.default.cachePath(forKey: link.parent.image.absoluteString))
        
        if let url = attributeSet.thumbnailURL, let image = UIImage(contentsOfFile: url.absoluteString) {
            attributeSet.thumbnailData = image.jpegData(compressionQuality: 0.8)
        } else { Log.info("Thumbnail cannot be saved to activity now for this anime. Will be saved later if needed.") }
        
        attributeSet.contentSources = [ link.parent.source.name ]
        attributeSet.contentDescription = link.name
        
        activity.contentAttributeSet = attributeSet
        
        activity.isEligibleForSearch = true
        activity.isEligibleForHandoff = true
        activity.isEligibleForPublicIndexing = false
        activity.needsSave = true
        
        // Expire after two days
        activity.expirationDate = Date() + 172800
        
        if #available(iOS 12.0, *) {
            activity.isEligibleForPrediction = false
            activity.persistentIdentifier = "\(identifier(for: link.parent.link)).\(link.identifier)"
        }
        
        // Will not update the user info yet. It should be updated by the video player later.
        return activity
    }
    
    /// Obtain the activity for resuming last watched anime
    ///
    /// This activity is meant for Siri Shortcuts and Sportlight
    static func activityForResumeLastAnime() -> NSUserActivity {
        let activity = NSUserActivity(activityType: activityTypeResumePlayback)
        
        activity.title = "Resume anime on NineAnimator"
        activity.keywords = [ "resume", "anime" ]
        
        activity.isEligibleForSearch = true
        activity.isEligibleForHandoff = false
        activity.isEligibleForPublicIndexing = true
        activity.needsSave = false
        
        if #available(iOS 12.0, *) {
            activity.isEligibleForPrediction = true
        }
        
        return activity
    }
    
    private static func identifier(for url: URL) -> String {
        String(url.hashValue, radix: 36, uppercase: true)
    }
}
