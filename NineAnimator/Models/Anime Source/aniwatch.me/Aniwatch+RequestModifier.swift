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

extension NASourceAniwatch {
    // MARK: XSRF Token For Aniwatch
    class XSRFTokenModifier: NARequestAdapter {
        weak var parent: NASourceAniwatch?

        init(parent: NASourceAniwatch) {
            self.parent = parent
        }
        
        // Attach XSRF-TOKEN cookie and header to every request
        func adapt(_ urlRequest: URLRequest, for session: Session) -> NineAnimatorPromise<NARequestAdaptingResult> {
            guard let parent = parent else { return .fail() }
            let cookieJar = HTTPCookieStorage.shared
            let aniWatchCookies = cookieJar.cookies(for: parent.endpointURL)
            // Use pre-existing XSRF token in cookieStore if possible, otherwise create new token and save to cookieStore for future use.
            let aniWatchXSRFCookie = aniWatchCookies?.first { cookie in
                cookie.name == "XSRF-TOKEN"
            } ?? _setXSRFCookie(cookieJar, token: _generateXSRFToken(length: 32))
            // Set the XSRF token in http headers
            let newRequest = _setXSRFHeader(for: urlRequest, token: aniWatchXSRFCookie.value)
            return .success(NARequestAdaptingResult.evaluateNext(request: newRequest))
        }
        
        // Create new cookie with XSRF token and save into cookieStore
        private func _setXSRFCookie(_ cookieJar: HTTPCookieStorage, token: String) -> HTTPCookie {
            let cookieProperties: [HTTPCookiePropertyKey: Any] = [
                .version: 1,
                .path: "/",
                .domain: ".aniwatch.me",
                .expires: Date.distantFuture,
                .name: "XSRF-TOKEN",
                .value: token
            ]
            let xsrfCookie = HTTPCookie(properties: cookieProperties)!
            cookieJar.setCookie(xsrfCookie)
            return xsrfCookie
        }
        
        // Add XSRF Token too http headers
        private func _setXSRFHeader(for request: URLRequest, token: String) -> URLRequest {
            var newRequest = request
            newRequest.addValue(token, forHTTPHeaderField: "x-xsrf-token")
            return newRequest
        }
        
        private func _generateXSRFToken(length: Int) -> String {
          let letters = "abcdefghijklmnopqrstuvwxyz0123456789"
          return String((0..<length).map { _ in letters.randomElement()! })
        }
    }
    // MARK: Authentication For Aniwatch
    class AuthSessionModifier: NARequestAdapter {
        weak var parent: NASourceAniwatch?
        
        init(parent: NASourceAniwatch) {
            self.parent = parent
        }
        
        let authenticatedActions = [
            "getAnime",
            "getEpisodes",
            "watchAnime"
        ]
        
        private struct HttpBodyController: Decodable {
            let action: String
            let controller: String
        }
        
        private struct SessionCookie: Decodable {
            let userid: Int
            let username: String
            let auth: String
        }
        
        // Attach session cookie to request, and auth token to http header
        func adapt(_ urlRequest: URLRequest, for session: Session) -> NineAnimatorPromise<NARequestAdaptingResult> {
            guard let parent = parent else { return .success(.fail()) }
            // Retrieve api action from http body of urlRequest. If no http body exists, do not attach auth token and session cookie
            guard let httpBody = urlRequest.httpBody else { return .success(.evaluateNext(request: urlRequest)) }
            let decoder = JSONDecoder()
            // Decode httpBodyController (Seems to be a standard thing in Aniwatch API)
            // We use httpBodyController to detect if user is requesting an authenticated endpoint
            guard let httpBodyController = try? decoder.decode(HttpBodyController.self, from: httpBody) else { return .fail(.decodeError("Cannot decode HTTP Body")) }
            let sessionCookie = _retrieveSessionCookie(for: parent.endpointURL)
            // If session cookie is NOT available, and user is accessing an AUTHENTICATED endpoint, throw Auth Required Error
            if let sessionCookieJSON = sessionCookie?.value       .removingPercentEncoding {
                // Decode Session Cookie JSON into SessionCookie object
                guard let sessionCookieObject = try? JSONDecoder().decode(SessionCookie.self, from: Data(sessionCookieJSON.utf8)) else { return .fail(.decodeError("Cannot Decode SessionCookie")) }
                // Attach auth token from SessionCookie into HTTP header
                var newRequest = urlRequest
                newRequest.addValue(sessionCookieObject.auth, forHTTPHeaderField: "x-auth")
                return .success(.evaluateNext(request: newRequest))
            } else if !authenticatedActions.contains(httpBodyController.action) {
                // User is trying to access public endpoint without sessionCookie
                return .success(.evaluateNext(request: urlRequest))
            } else {
                // User is tring to access private endpoint without sessionCookie
                return .fail(.authenticationRequiredError("Please login to Aniwatch", URL(string: "https://aniwatch.me/login")!))
            }
        }
        
        // Retrieves Session Cookie from local storage if available
        private func _retrieveSessionCookie(for aniWatchUrl: URL) -> HTTPCookie? {
            // Use local cookie store first
            let localAniwatchCookies = HTTPCookieStorage.shared.cookies(for: aniWatchUrl)
            let localAniwatchSessionCookie = localAniwatchCookies?.first { cookie in
                cookie.name == "SESSION"
            }
            return localAniwatchSessionCookie
        }
    }
}
