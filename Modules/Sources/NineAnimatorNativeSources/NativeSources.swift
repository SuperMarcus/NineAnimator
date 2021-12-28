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
import NineAnimatorCommon

public enum NativeSources {
    internal static var initialized = false
    
    /// Register the default set of sources
    public static func initialize() {
        guard !initialized else { return }
        
        let registry = NineAnimator.default
        
        registry.register(sourceType: NASourceAnimePahe.self)
        registry.register(sourceType: NASourceFourAnime.self)
        registry.register(sourceType: NASourceAnimeTwist.self)
        registry.register(sourceType: NASourcePantsubase.self)
        registry.register(sourceType: NASourceAnimeUltima.self)
        registry.register(sourceType: NASourceAnimeKisa.self)
        registry.register(sourceType: NASourceAnimeKisa.ExperimentalSource.self)
        registry.register(sourceType: NASourceHAnime.self)
        registry.register(sourceType: NASourceGogoAnime.self)
        registry.register(sourceType: NASourceAnimeDao.self)
        registry.register(sourceType: NASourceAnimeHub.self)
        registry.register(sourceType: NASourceArrayanime.self)
        registry.register(sourceType: NASourceKissanime.self)
        registry.register(sourceType: NASourceAnimeUnity.self)
        registry.register(sourceType: NASourceMonosChinos.self)
        registry.register(sourceType: NASourceAnimeSaturn.self)
        registry.register(sourceType: NASourceAnimeWorld.self)
        registry.register(sourceType: NASourceAnimeFlv.self)
        
        // Disabled sources
        registry.register(sourceType: NASourceWonderfulSubs.self)
        registry.register(sourceType: NASourceMasterAnime.self)
        registry.register(sourceType: NASourceNineAnime.self)
        registry.register(sourceType: NASourceAniwatch.self)
        
        initialized = true
    }
}
