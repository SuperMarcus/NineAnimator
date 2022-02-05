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
import Kingfisher
import NineAnimatorCommon

extension NASourceHentaiWorld: Kingfisher.ImageDownloadRequestModifier {
    /// Setup Kingfisher modifier for verified requests to resources
    func setupGlobalRequestModifier() {
        parent.registerAdditionalImageModifier(self)
    }
    
    func modified(for request: URLRequest) -> URLRequest? {
        var modifiedRequest: URLRequest? = request
        if let requestingUrl = request.url, requestingUrl.host == endpointURL.host {
            modifiedRequest?.setValue(sessionUserAgent, forHTTPHeaderField: "User-Agent")
        }
        return modifiedRequest
    }
}
