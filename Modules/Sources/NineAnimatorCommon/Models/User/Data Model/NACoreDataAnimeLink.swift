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

@objc(NACoreDataAnimeLink)
public class NACoreDataAnimeLink: NACoreDataAnyLink {
    public var nativeAnimeLink: AnimeLink? {
        guard let title = self.name,
            let link = self.url,
            let sourceName = self.sourceName else {
            Log.error("[NACoreDataAnimeLink] Potential data corruption: missing one or more attributes.")
            return nil
        }
        
        guard let source = NineAnimator.default.source(with: sourceName) else {
            Log.error("[NACoreDataAnimeLink] Unknown source '%@'. Is the app outdated?", sourceName)
            return nil
        }
        
        let artwork = self.artwork ?? NineAnimator.placeholderArtworkUrl
        
        return AnimeLink(title: title, link: link, image: artwork, source: source)
    }
    
    public func updateAttributes(withAnimeLink animeLink: AnimeLink) {
        guard url == animeLink.link else {
            return Log.error(
                "[NACoreDataAnimeLink] Trying to update CoreData AnimeLink ('%@') with unequivalent native AnimeLink ('%@').",
                url?.absoluteString ?? "undefined",
                animeLink.link.absoluteString
            )
        }
        
        self.name = animeLink.title
        self.artwork = animeLink.image
    }
    
    public convenience init(initialAnimeLink animeLink: AnimeLink, context: NSManagedObjectContext) {
        self.init(context: context)
        self.url = animeLink.link
        self.name = animeLink.title
        self.artwork = animeLink.image
        self.sourceName = animeLink.source.name
    }
}
