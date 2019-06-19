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

import AVFoundation
import CoreData
import Foundation

@objc(PersistentEpisode)
public class PersistentEpisode: NSManagedObject {
    /// Get the episode link for this persistent episode
    var episodeLink: EpisodeLink {
        get { return try! PropertyListDecoder().decode(EpisodeLink.self, from: self.episodeLinkData!) }
        set { self.episodeLinkData = try! PropertyListEncoder().encode(newValue) }
    }
    
    /// Get the resource path
    var resourceUrl: URL? {
        get {
            var isBookmarkStalled = false
            if let bookmarkData = self.bookmarkData,
                let resourceUrl = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isBookmarkStalled) {
                // Check if the bookmark is stalled
                if isBookmarkStalled {
                    Log.error("[PersistentEpisode] Resource bookmark for %@ is stalled", episodeLink)
                } else { return resourceUrl }
            }
            return nil
        }
        set {
            // Convert the URL to bookmark
            if let resourceUrl = newValue,
                let bookmarkData = try? resourceUrl.bookmarkData() {
                self.bookmarkData = bookmarkData
            } else { self.bookmarkData = nil }
        }
    }
    
    /// A reference to the current downloading task
    var taskReference: URLSessionDownloadTask?
}
