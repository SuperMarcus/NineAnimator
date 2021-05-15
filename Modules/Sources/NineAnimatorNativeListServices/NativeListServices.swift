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

public enum NativeListServices {
    internal static var initialized = false
    
    /// Register the default set of sources
    public static func initialize() {
        guard !initialized else { return }
        
        let registry = NineAnimator.default
        
        registry.register(serviceType: Anilist.self)
        registry.register(serviceType: Kitsu.self)
        registry.register(serviceType: MyAnimeList.self)
        registry.register(serviceType: Simkl.self)
        
        initialized = true
    }
}
