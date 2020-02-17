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
            var responseParameters: [String: String]?
            
            // Parse the necessary components and include that in the error
            do {
                let bowl = try SwiftSoup.parse(bodyString)
                let challengeForm = try bowl.select("#challenge-form")
                let challengeResponsePath = try challengeForm.attr("action")
                
                let cfJschlVcValue = try challengeForm.select("input[name=jschl_vc]").attr("value")
                let cfPassValue = try challengeForm.select("input[name=pass]").attr("value")
                let cfRValue = try challengeForm.select("input[name=r]").attr("value")
                let cfJschlAnswerValue = try _cloudflareWAFSolveChallenge(
                    bodyString,
                    requestingUrl: requestingUrl
                ).tryUnwrap(.decodeError("unable to resolve cloudflare challenge"))
                
                passthroughUrl = try URL(
                    string: challengeResponsePath,
                    relativeTo: requestingUrl
                ).tryUnwrap()
                
                responseParameters = [
                    "r": cfRValue,
                    "jschl_vc": cfJschlVcValue,
                    "pass": cfPassValue,
                    "jschl_answer": cfJschlAnswerValue
                ]
                
                Log.info("[CF_WAF] Detected a potentially solvable WAF challenge")
            } catch {
                Log.info(
                    "[CF_WAF] Cannot find all necessary components to solve Cloudflare challenges: %@",
                    error
                )
            }
            
            return .failure(
                NineAnimatorError.CloudflareAuthenticationChallenge(
                    authenticationUrl: passthroughUrl,
                    responseParameters: responseParameters
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
            pattern: "getElementById\\('cf-content'\\)[\\s\\S]+?setTimeout.+?\\r?\\n([\\s\\S]+?a\\.value\\s*=.+?)\\r?\\n(?:[^{<>]*\\},\\s*(\\d{4,}))?",
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
            of: " '; 121'",
            with: "",
            options: [ .regularExpression ]
        )
        
        // Fix dead code
        solveJs = solveJs.replacingOccurrences(
            of: "document.createElement('div')",
            with: "{ innerHTML: \"\", firstChild: { href: \"https://\(requestingUrl.host ?? "doesnotmatter.com")/\" } }"
        )
        
        // Replace `t.length` with the length of the host string
        solveJs = solveJs.replacingOccurrences(
            of: "t.length",
            with: "\(hostLength)"
        )
        
        solveJs = solveJs.replacingOccurrences(
            of: "document\\.getElementById\\('jschl-answer'\\);",
            with: "{ value: 0 }",
            options: [ .regularExpression ]
        )
        
        // Evaluate the javascript and return the value
        // JSContext is a safe and sandboxed environment, so no need to run in vm like node
        if let context = JSContext() {
            let definingDocumentContext = NSMutableDictionary()
            let domDocumentKey: NSString = "document"
            
            let domGetElementById: @convention(block) (String, String) -> Any = {
                [challengePageContent] domId, second in
                do {
                    Log.debug("[CF_WAF] Get DOM Element %@", domId)
                    let bowl = try SwiftSoup.parse(challengePageContent)
                    let element = try bowl.select("#\(domId)")
                    if !element.isEmpty() {
                        return [ "innerHTML": try element.html() ]
                    } else { throw NineAnimatorError.responseError("Key \(domId) doesn't exist") }
                } catch { Log.error("[CF_WAF] Error running challenge script: %@", error) }
                
                // Return null for not found
                return NSNull()
            }
            definingDocumentContext["getElementById"] = domGetElementById
            
            context.setObject(
                definingDocumentContext,
                forKeyedSubscript: domDocumentKey
            )
            
            return context.evaluateScript(solveJs)?.toString()
        }
        
        return nil
    }
}

// MARK: - Retry request
extension BaseSource: Alamofire.RequestRetrier {
    func should(_ manager: SessionManager,
                retry request: Request,
                with error: Error,
                completion: @escaping RequestRetryCompletion) {
        // Assign self as the source of error
        if let error = error as? NineAnimatorError {
            error.sourceOfError = self
        }
        
        // Call the completion handler
        func fail() {
            completion(false, 0)
        }
        
        // We will not retry this since app is not actively running in the foreground
        if AppDelegate.shared?.isActive != true {
            return fail()
        }
        
        // Check if there is an cloudflare authentication error
        if let error = error as? NineAnimatorError.CloudflareAuthenticationChallenge,
            let verificationUrl = error.authenticationUrl {
            // Return fail if challenge solver is not enabled
            if !NineAnimator.default.user.solveFirewallChalleges {
                Log.info("[CF_WAF] Encountered a solvable challenge but the autoresolver has been disabled. Falling back to manual authentication.")
                return fail()
            }
            
            // Abort after 2 tries
            if request.retryCount > 1 {
                Log.info("[CF_WAF] Maximal number of retry reached, renewing identity.")
                self.renewIdentity()
                for cookie in HTTPCookieStorage.shared.cookies(for: verificationUrl) ?? [] {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                }
                return fail()
            }
            
            let delay: DispatchTimeInterval = .seconds(4)
            Log.info("[CF_WAF] Attempting to solve cloudflare WAF challenge...continues after %@ seconds", delay)
            
            // Solve the challenge in 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let originalUrl = request.request?.url,
                    let urlScheme = originalUrl.scheme,
                    let urlHost = originalUrl.host
                    else { return fail() }
                let originalUrlString = originalUrl.absoluteString
                var originUrl = "\(urlScheme)://\(urlHost)"
                
                if let port = originalUrl.port {
                    originUrl += ":\(port)"
                }
                
                Log.info("[CF_WAF] Sending cf resolve challenge request...")
                
                // Make the verification request and then call the retry handler
                self.browseSession.request(
                    verificationUrl,
                    method: .post,
                    parameters: error.authenticationResponse,
                    encoding: CFResponseEncoder.shared,
                    headers: [
                        "Referer": originalUrlString,
//                        "Pragma": "no-cache",
//                        "Cache-Control": "no-cache",
                        "Origin": originUrl,
                        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                    ]
                ) .responseData {
                    value in
                    guard case .success = value.result,
                        let headerFields = value.response?.allHeaderFields as? [String: String]
                        else { return fail() }
                    
                    // Check if clearance has been granted. If not, renew the current identity
                    let verificationResponseCookies = HTTPCookie.cookies(
                        withResponseHeaderFields: headerFields,
                        for: verificationUrl
                    )
                    
                    if verificationResponseCookies.contains(where: { $0.name == "cf_clearance" }) {
                        Log.info("[CF_WAF] Clearance has been granted")
                    }
                    
                    Log.info("[CF_WAF] Resuming original request...")
                    completion(true, 0.2)
                }
            }
            
            // Return without calling the completion handler
            return
        }
        
        // Default to no retry
        fail()
    }
}

// MARK: - Response Encoder
private extension BaseSource {
    class CFResponseEncoder: Alamofire.ParameterEncoding {
        static let shared = CFResponseEncoder()
        
        func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
            var encodedUrlRequest = try urlRequest.asURLRequest()
            
            var cfFilteredCharacters = CharacterSet.urlFragmentAllowed
            _ = cfFilteredCharacters.remove("/")
            _ = cfFilteredCharacters.remove("=")
            _ = cfFilteredCharacters.remove("+")
            
            if let parameters = parameters {
                let encodedParameters = parameters.compactMap {
                    key, value -> String? in
                    let encodedKey = key
                        .removingPercentEncoding?
                        .addingPercentEncoding(
                            withAllowedCharacters: cfFilteredCharacters
                        )
                    let encodedValue = String(describing: value)
                        .removingPercentEncoding?
                        .addingPercentEncoding(
                            withAllowedCharacters: cfFilteredCharacters
                        )
                    
                    if let encodedKey = encodedKey, let encodedValue = encodedValue {
                        return encodedKey + "=" + encodedValue
                    } else { return nil }
                } .joined(separator: "&")
                
                encodedUrlRequest.httpBody = try encodedParameters
                    .data(using: .utf8)
                    .tryUnwrap()
                
                if encodedUrlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                    encodedUrlRequest.setValue(
                        "application/x-www-form-urlencoded",
                        forHTTPHeaderField: "Content-Type"
                    )
                }
            }
            
            return encodedUrlRequest
        }
    }
}
