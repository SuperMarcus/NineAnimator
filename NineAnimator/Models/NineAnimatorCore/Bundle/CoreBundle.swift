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

import CryptoKit
import Foundation
import JavaScriptCore
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources

@available(iOS 13.0, *)
class NACoreEngineBundle: NSObject {
    let provider: NACoreEngineBundleProvider
    let manifest: Manifest
    let publicKey: SigningKey
    
    init(_ manifest: Manifest, publicKey: SigningKey, provider: NACoreEngineBundleProvider) {
        self.provider = provider
        self.manifest = manifest
        self.publicKey = publicKey
        
        super.init()
    }
}
