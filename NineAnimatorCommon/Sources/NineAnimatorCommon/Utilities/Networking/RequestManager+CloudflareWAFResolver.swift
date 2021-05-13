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

public class CloudflareWAFResolver {
    private(set) weak var parent: NARequestManager?
    
    public init(parent: NARequestManager) {
        self.parent = parent
    }
    
    /// A middleware that resolves into an error and attempts to resolve it if a Cloudflare WAF challenge has been detected
    public static func middleware(
        request: URLRequest?,
        response: HTTPURLResponse,
        body: Data?) -> Alamofire.DataRequest.ValidationResult {
        if let requestingUrl = request?.url,
            (400..<500).contains(response.statusCode) || response.statusCode == 503,
            let serverHeaderField = response.allHeaderFields["Server"] as? String,
            serverHeaderField.lowercased().hasPrefix("cloudflare"),
            let body = body,
            let bodyString = String(data: body, encoding: .utf8),
            bodyString.contains("challenge-form"),
            bodyString.localizedCaseInsensitiveContains("cloudflare") {
            // Save the requestingUrl for modification
            var passthroughUrl: URL?
            var responseParameters: [String: String]?
            
            // Parse the necessary components and include that in the error
            do {
                let bowl = try SwiftSoup.parse(bodyString)
                let challengeForm = try bowl.select("#challenge-form")
                let challengeResponsePath = try challengeForm.attr("action")
                
                passthroughUrl = try URL(
                    string: challengeResponsePath,
                    relativeTo: requestingUrl
                ).tryUnwrap()
                
                let cfJschlVcValue = try challengeForm.select("input[name=jschl_vc]").attr("value")
                let cfPassValue = try challengeForm.select("input[name=pass]").attr("value")
                let cfRValue = try challengeForm.select("input[name=r]").attr("value")
                let cfJschlAnswerValue = try _cloudflareWAFSolveChallenge(
                    bodyString,
                    requestingUrl: requestingUrl
                ).tryUnwrap(.decodeError("unable to resolve cloudflare challenge"))
                
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
        return .success(())
    }
}

// MARK: - Retrier
// extension CloudflareWAFResolver {
//    func retry(_ request: Request, for session: Session, dueTo inputError: Error) -> NineAnimatorPromise<NARequestRetryDirective> {
//        let error: NineAnimatorError.CloudflareAuthenticationChallenge
//
//        if let retryError = inputError as? NineAnimatorError.CloudflareAuthenticationChallenge {
//            error = retryError
//        } else if let afError = inputError as? AFError, // Extract the underlying error
//            let challengeError = afError.underlyingError as? NineAnimatorError.CloudflareAuthenticationChallenge {
//            error = challengeError
//        } else {
//            return .success(.evaluateNext)
//        }
//
//        guard let verificationUrl = error.authenticationUrl,
//            let authenticationResponse = error.authenticationResponse else {
//            return .success(.evaluateNext)
//        }
//
//        // Return fail if challenge solver is not enabled
//        if !NineAnimator.default.user.solveFirewallChalleges {
//            Log.info("[CloudflareWAFResolver] Encountered a solvable challenge but the autoresolver has been disabled.")
//            return .success(.evaluateNext)
//        }
//
//        // We will not retry this since app is not actively running in the foreground
//        if AppDelegate.shared?.isActive != true {
//            Log.info("[CloudflareWAFResolver] Encountered a solvable challenge but the app is inactive.")
//            return .success(.evaluateNext)
//        }
//
//        // Assign the parent `BaseSource` as the source of error
//        error.sourceOfError = self.parent
//
//        // Abort after 2 tries
//        if request.retryCount > 1 {
//            Log.info("[CloudflareWAFResolver] Maximal number of retry reached, renewing identity.")
//            for cookie in HTTPCookieStorage.shared.cookies(for: verificationUrl) ?? [] {
//                HTTPCookieStorage.shared.deleteCookie(cookie)
//            }
//
//            // Renew identity with a delay
//            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
//                [weak self] in self?.parent?.renewIdentity()
//            }
//
//            return .success(.fail(error: nil))
//        }
//
//        // Create an empty promise
//        let promise = NineAnimatorPromise<NARequestRetryDirective> {
//            _ in nil
//        }
//
//        let delay: DispatchTimeInterval = .seconds(4)
//        Log.info("[CloudflareWAFResolver] Attempting to solve cloudflare WAF challenge...continues after %@ seconds", delay)
//
//        // Solve the challenge in 5 seconds
//        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//            [weak request, weak promise, weak parent] in
//            guard let promise = promise else {
//                return Log.error("[CloudflareWAFResolve] Cannot continue because reference to the promise has been lost")
//            }
//
//            // Request cancelled during the retry process
//            guard let request = request,
//                request.isCancelled == false,
//                let parent = parent else {
//                promise.reject(NineAnimatorError.unknownError)
//                return
//            }
//
//            guard let originalUrl = request.request?.url,
//                let urlScheme = originalUrl.scheme,
//                let urlHost = originalUrl.host else {
//                return promise.reject(NineAnimatorError.unknownError)
//            }
//
//            let originalUrlString = originalUrl.absoluteString
//            var originUrl = "\(urlScheme)://\(urlHost)"
//
//            if let port = originalUrl.port {
//                originUrl += ":\(port)"
//            }
//
//            Log.info("[CloudflareWAFResolve] Sending cf resolve challenge request...")
//
//            // Make the verification request and then call the retry handler
//            parent.browseSession.request(
//                verificationUrl,
//                method: .post,
//                parameters: authenticationResponse,
//                encoding: CFResponseEncoder.shared,
//                headers: [
//                    "Referer": originalUrlString,
//                    "Origin": originUrl,
//                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
//                ]
//            ) .responseData {
//                [weak promise] value in
//                guard let promise = promise else {
//                    return Log.error("[CloudflareWAFResolver] Cannot continue because reference to the promise has been lost")
//                }
//
//                guard case .success = value.result,
//                    let headerFields = value.response?.allHeaderFields as? [String: String] else {
//                    Log.error("[CloudflareWAFResolver] Cannot continue because challenge response does not include valid header fields")
//                    return promise.resolve(.evaluateNext)
//                }
//
//                // Check if clearance has been granted. If not, renew the current identity
//                let verificationResponseCookies = HTTPCookie.cookies(
//                    withResponseHeaderFields: headerFields,
//                    for: verificationUrl
//                )
//
//                if verificationResponseCookies.contains(where: { $0.name == "cf_clearance" }) {
//                    Log.info("[CloudflareWAFResolver] Clearance has been granted")
//                }
//
//                Log.info("[CloudflareWAFResolver] Resuming original request...")
//
//                // Retry after 0.5 seconds
//                promise.resolve(.retry(delay: 0.5))
//            }
//        }
//
//        return promise
//    }
// }

// MARK: - Challenge Resolver
private extension CloudflareWAFResolver {
    /// Obtain the jschl_answer field from the challenge page
    ///
    /// ### References
    /// [1] [cloudflare-scrape](https://github.com/Anorov/cloudflare-scrape/blob/master/cfscrape/__init__.py)
    /// [2] [cloudscraper](https://github.com/codemanki/cloudscraper/blob/master/index.js)
    private static func _cloudflareWAFSolveChallenge(_ challengePageContent: String, requestingUrl: URL) -> String? {
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
                [challengePageContent] domId, _ in
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

// MARK: - Stubs & Decoder
private extension CloudflareWAFResolver {
    /// Custom parameter encoder for Cloudflare challenge responses
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
