//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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
import JavaScriptCore
import SwiftSoup

// MARK: - WAF Detection
extension BaseSource {
    /// Detects the presence of a cloudflare WAF verification page
    static func _cloudflareWAFVerificationMiddleware(
        request: URLRequest?,
        response: HTTPURLResponse,
        body: Data?
        ) -> Alamofire.DataRequest.ValidationResult {
        if let requestingUrl = request?.url,
            let serverHeaderField = response.allHeaderFields["Server"] as? String,
            serverHeaderField.lowercased().hasPrefix("cloudflare"),
            let body = body,
            let bodyString = String(data: body, encoding: .utf8),
            bodyString.contains("jschl_vc"),
            bodyString.contains("jschl_answer") {
            // Save the requestingUrl for modification
            var passthroughUrl: URL?
            
            // Parse the necessary components and include that in the error
            do {
                let bowl = try SwiftSoup.parse(bodyString)
                let cfJschlVcValue = try bowl.select("input[name=jschl_vc]").attr("value")
                let cfPassValue = try bowl.select("input[name=pass]").attr("value")
                let cfSValue = try bowl.select("input[name=s]").attr("value")
                let cfJschlAnswerValue = try some(
                    _cloudflareWAFSolveChallenge(bodyString, requestingUrl: requestingUrl),
                    or: .decodeError
                )
                
                guard let challengeScheme = requestingUrl.scheme,
                    let challengeHost = requestingUrl.host,
                    let challengeUrl = URL(string: "\(challengeScheme)://\(challengeHost)/cdn-cgi/l/chk_jschl")
                    else { throw NineAnimatorError.urlError }
                
                // Reconstruct the url with cloudflare challenge value stored in the fragment
                var urlBuilder = URLComponents(url: challengeUrl, resolvingAgainstBaseURL: false)
                urlBuilder?.queryItems = [
                    .init(name: "s", value: cfSValue.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)),
                    .init(name: "jschl_vc", value: cfJschlVcValue.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)),
                    .init(name: "pass", value: cfPassValue.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)),
                    .init(name: "jschl_answer", value: cfJschlAnswerValue)
                ]
                
                Log.info("[CF_WAF] Detected a potentially solvable WAF challenge")
                
                // Store passthrough url
                passthroughUrl = try some(urlBuilder?.url, or: .urlError)
            } catch { Log.info("Cannot find all necessary components to solve Cloudflare challenges.") }
            
            return .failure(
                NineAnimatorError.authenticationRequiredError(
                    "The website had asked NineAnimator to verify that you are not an attacker. Please complete the challenge in the opening page. When you are finished, close the page and NineAnimator will attempt to load the resource again.",
                    passthroughUrl
                )
            )
        }
        return .success
    }
    
    /// Obtain the jschl_answer field from the challenge page
    ///
    /// ### References
    /// [1] [cloudflare-scrape](https://github.com/Anorov/cloudflare-scrape/blob/master/cfscrape/__init__.py)
    /// [2] [cloudscraper](https://github.com/codemanki/cloudscraper/blob/master/index.js)
    fileprivate static func _cloudflareWAFSolveChallenge(_ challengePageContent: String, requestingUrl: URL) -> String? {
        let jsMatchingRegex = try! NSRegularExpression(
            pattern: "(var\\s+s,t,o,p,b,r,e[^}]+\\}[^}]+)",
            options: []
        )
        
        // Obtain the raw resolver portion of the js
        guard var solveJs = jsMatchingRegex.firstMatch(in: challengePageContent)?.firstMatchingGroup else {
            return nil
        }
        
        // Obtain the length of the host
        guard let hostLength = requestingUrl.host?.count else { return nil }
        
        // Directly return the resolved value instead of assigning it to the form
        solveJs = solveJs.replacingOccurrences(
            of: "a\\.value = (.+ \\+ t\\.length(\\).toFixed\\(10\\))?).+",
            with: "$1",
            options: [ .regularExpression ]
        )
        
        // Remove the submit form statements
        solveJs = solveJs.replacingOccurrences(
            of: "f.action(?:.+|\\s)+$",
            with: "",
            options: [ .regularExpression ]
        )
        
        // Remove all form assignments
        solveJs = solveJs.replacingOccurrences(
            of: "\\s{3,}[a-z](?: = |\\.).+",
            with: "",
            options: [ .regularExpression ]
        )
        
        // Replace `t.length` with the length of the host string
        solveJs = solveJs.replacingOccurrences(
            of: "t.length",
            with: "\(hostLength)"
        )
        
        // Evaluate the javascript and return the value
        // JSContext is a safe and sandboxed environment, so no need to run in vm like node
        let context = JSContext()
        return context?.evaluateScript(solveJs)?.toString()
    }
}

// MARK: - Retry request
extension BaseSource: Alamofire.RequestRetrier {
    func should(_ manager: SessionManager,
                retry request: Request,
                with error: Error,
                completion: @escaping RequestRetryCompletion) {
        // Call the completion handler
        func fail() {
            Log.info("[CF_WAF] Failed to resolve cloudflare challenge")
            completion(false, 0)
        }
        
        // Check if there is an cloudflare authentication error
        if let error = error as? NineAnimatorError {
            switch error {
            case let .authenticationRequiredError(_, vUrl):
                guard let verificationUrl = vUrl else { break }
                
                // Abort after 4 retries
                if request.retryCount > 4 {
                    Log.info("[CF_WAF] Maximal number of retry reached.")
                    return fail()
                }
                
                Log.info("[CF_WAF] Attempting to solve cloudflare WAF challenge...continues after 7 seconds")
                
                // Solve the challenge in 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                    guard let originalUrlString = request.request?.url?.absoluteString
                        else { return fail() }
                    
                    Log.info("[CF_WAF] Sending cf resolve challenge request...")
                    
                    // Make the verification request and then call the retry handler
                    manager.request(verificationUrl, headers: [
                        "Referer": originalUrlString,
                        "User-Agent": self.sessionUserAgent,
                        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                    ]) .responseData {
                        [weak self] value in
                        guard self != nil, case .success = value.result else { return fail() }
                        
                        Log.info("[CF_WAF] Resuming original request...")
                        completion(true, 0.2)
                    }
                }
                
                // Return without calling the completion handler
                return
            default: break
            }
        }
        
        // Default to no retry
        fail()
    }
}
