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

import Alamofire
import Foundation

extension NASourceNineAnime {
    class func _verificationDetectionMiddleware(
        request: URLRequest?,
        response: HTTPURLResponse,
        body: Data?
    ) -> Alamofire.DataRequest.ValidationResult {
        if let url = request?.url,
            let body = body,
            let bodyString = String(data: body, encoding: .utf8),
            bodyString.contains("Please complete the security check to continue") {
            return .failure(
                NineAnimatorError.authenticationRequiredError(
                    "An authentication is required by 9anime for you to continute.",
                    url
                )
            )
        } else { return .success(()) }
    }
    
    class func _ipBlockDetectionMiddleware(
        request: URLRequest?,
        response: HTTPURLResponse,
        body: Data?
    ) -> Alamofire.DataRequest.ValidationResult {
        if let body = body, body.count < 1000, // < 1kb body is abnormal
            let bodyString = String(data: body, encoding: .utf8),
            bodyString.localizedCaseInsensitiveContains("temporarily blocks")
            && bodyString.localizedCaseInsensitiveContains("harmful requests") {
            return .failure(
                NineAnimatorError.contentUnavailableError(
                    "This client may be blocked. Make sure you're using an up-to-date version of NineAnimator."
                )
            )
        }
        return .success(())
    }
    
    //9anime returns 503 instead of 404 status when request not found
    class func _contentNotFoundMiddleware(
        request: URLRequest?,
        response: HTTPURLResponse,
        body: Data?
    ) -> Alamofire.DataRequest.ValidationResult {
        if let body = body, response.statusCode == 503,
            let bodyString = String(data: body, encoding: .utf8),
            bodyString.localizedCaseInsensitiveContains("Error 404")
            && bodyString.localizedCaseInsensitiveContains("NotFound") {
            return .failure(
                NineAnimatorError.contentUnavailableError(
                    "This anime could not be found."
                )
            )
        }
        return .success(())
    }
}
