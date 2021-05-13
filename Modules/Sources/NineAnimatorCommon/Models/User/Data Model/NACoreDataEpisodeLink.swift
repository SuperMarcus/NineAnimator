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

@objc(NACoreDataEpisodeLink)
public class NACoreDataEpisodeLink: NSManagedObject {
    public var nativeEpisodeLink: EpisodeLink? {
        guard let parentAnimeLink = parent?.nativeAnimeLink else {
            Log.error("[NACoreDataEpisodeLink] Potential data corruption: trying to read a parent-less CoreData EpisodeLink.")
            return nil
        }
        
        guard let identifier = self.identifier,
            let name = self.name,
            let server = self.server else {
            Log.error("[NACoreDataEpisodeLink] Potential data corruption: missing one or more attributes.")
            return nil
        }
        
        return EpisodeLink(
            identifier: identifier,
            name: name,
            server: server,
            parent: parentAnimeLink
        )
    }
}
