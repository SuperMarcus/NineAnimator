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
import JavaScriptCore

@available(iOS 13, *)
extension NACoreEngine {
    var _coreEngineFetch: @convention(block) () -> JSValue? {
        { [weak self] in
            guard let self = self else {
                Log.error("[NACoreEngine.FetchAPI] Fetch function called to a released engine object.")
                return nil
            }
            
            guard let arguments = JSContext.currentArguments() as? [JSValue] else {
                Log.error("[NACoreEngine.FetchAPI] Cannot obtain the list of arguments. Is the fetch block called by native code?")
                return nil
            }
            
            
            
            return nil
        }
    }
}
