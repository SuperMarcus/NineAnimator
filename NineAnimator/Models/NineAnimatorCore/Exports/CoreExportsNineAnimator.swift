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

/// The `NineAnimator` object exposed to the JavaScript environment.
@available(iOS 13, *)
@objc protocol NACoreEngineExportsNineAnimatorProtocol: JSExport {
    /// NineAnimator app version
    var version: String { get }
    
    /// NineAnimator app build
    var build: Int { get }
    
    /// Fetch API `NineAnimator.fetch` exposed to the JavaScript environment.
    /// - Parameters:
    ///   - resource: The resource locator for the fetch operation. Corresponds to the first argument of the `fetch` function.
    ///   - init: Fetch initialization options. Corresponds to the second argument of the `fetch` function. See `NACoreEngineExportsNineAnimator.FetchInitOptions` for details.
    func fetch(_ resource: String, _ `init`: NSDictionary?) -> JSValue?
}

@available(iOS 13, *)
@objc class NACoreEngineExportsNineAnimator: NSObject, NACoreEngineExportsNineAnimatorProtocol {
    dynamic var version: String {
        NineAnimator.default.version
    }
    
    dynamic var build: Int {
        NineAnimator.default.buildNumber
    }
    
    unowned var coreEngine: NACoreEngine
    var jsContext: JSContext { coreEngine.jsContext }
    
    init(parent: NACoreEngine) {
        self.coreEngine = parent
    }
}
