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

/**
 A central model for user data and preferences.
 
 This class is used to manage all the user data such as playback
 progresses, search history, and viewing history. In a nutshell,
 it's a wrapper for UserDefaults, and may be used (although not
 yet implemented) to integrate with other websites like MAL,
 AniList, or Kitsu.
 */
class NineAnimatorUser {
    let _freezer = UserDefaults.standard
    
    /// A list of server identifiers that has been silenced from presenting warnings regarding unrecommended use
    var _silencedUnrecommendedServerPurposes = [Anime.ServerIdentifier: Set<VideoProviderParser.Purpose>]()
    
    /// Underlying CoreData store
    let coreDataLibrary = NACoreDataLibrary()
    
    /// Remove all default entries and the coredata library
    func clearAll() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        _freezer.removePersistentDomain(forName: bundleId)
        coreDataLibrary.reset()
    }
}
