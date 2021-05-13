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
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources

/// FetchAPI Response object
@available(iOS 13, *)
@objc protocol NACoreEngineExportsResponseProtocol: JSExport {
    var headers: [String: String] { get }
    var ok: Bool { get }
    var redirected: Bool { get }
    var status: Int { get }
    var statusText: String { get }
    var url: String { get }
    
    /// Returns a JavaScript promise that resolves into a JSON object.
    func json() -> JSValue?
    
    /// Returns a JavaScript promise that resolves into a string.
    func text() -> JSValue?
}

@available(iOS 13, *)
extension NACoreEngineExportsNineAnimator {
    /// See `NACoreEngineExportsNineAnimatorProtocol.fetch` for documents.
    func fetch(_ resourceEndpointString: String, _ initOptionsRaw: NSDictionary?) -> JSValue? {
        do {
            Log.info("[NineAnimatorCore.NineAnimator.FetchAPI] Requesting to %@, options %@", resourceEndpointString, String(describing: initOptionsRaw))
            
            let initOptions: FetchInitOptions
            
            if let initOptionsRaw = initOptionsRaw {
                initOptions = try DictionaryDecoder().decode(FetchInitOptions.self, from: initOptionsRaw)
            } else {
                initOptions = FetchInitOptions()
            }
            
            // Combine headers
            var requestHeaders = HTTPHeaders()
            
            if let inferredBodyType = initOptions.bodyContentType {
                requestHeaders["Content-Type"] = inferredBodyType
            }
            
            if let referer = initOptions.referer {
                requestHeaders["Referer"] = referer
            }
            
            if let overridingHeaders = initOptions.headers {
                overridingHeaders.forEach {
                    requestHeaders[$0.key] = $0.value
                }
            }
            
            let resourceEndpoint = try URL(string: resourceEndpointString).tryUnwrap(.urlError)
            var urlRequest = try URLRequest(
                url: resourceEndpoint,
                method: initOptions.method,
                headers: requestHeaders
            )
            
            if let requestBodyData = initOptions.body {
                urlRequest.httpBody = requestBodyData
            }
            
            let responseObject = FetchResponse(engine: self.coreEngine)
            let requestPromise = self.coreEngine.requestManager.request(
                urlRequest: urlRequest,
                handling: initOptions.handling
            ) .onReceivingResponse {
                [weak responseObject] dataResponse in
                guard let responseObject = responseObject else {
                    return Log.error("[NineAnimatorCore.NineAnimator.FetchAPI] Result object deallocted when handling the response.")
                }
                
                // Store response information
                if let response = dataResponse.response {
                    responseObject.headers = Dictionary(uniqueKeysWithValues: response.headers.dictionary.map {
                        ($0.lowercased(), $1) // All lower-cased keys for headers
                    })
                    responseObject.status = response.statusCode
                    // Whatever
                    responseObject.statusText = HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
                    responseObject.url = response.url?.absoluteString ?? ""
                } else {
                    Log.error("[NineAnimatorCore.NineAnimator.FetchAPI] Request completed without a response object.")
                }
                
                // Debug loggings
                if !responseObject.ok {
                    Log.debug("[NineAnimatorCore.NineAnimator.FetchAPI] Request completed with abnormal status code %@", responseObject.status)
                }
            } .responseData
              .then {
                [responseObject, weak self] respondedData -> JSValue? in
                guard let self = self else { return nil }
                responseObject.responseData = respondedData
                return JSValue(object: responseObject, in: self.jsContext)
            }
            
            return self.coreEngine.retainNativePromise(requestPromise)
        } catch {
            Log.debug("[NineAnimatorCore.NineAnimator.FetchAPI] Failed to initiate the fetch operation because of an error: %@", error)
            return JSValue(
                newPromiseRejectedWithReason: coreEngine.convertToJSError(error as NSError),
                in: self.jsContext
            )
        }
    }
}

// MARK: - FetchAPI.InitOptions
@available(iOS 13, *)
private extension NACoreEngineExportsNineAnimator {
    enum FetchInitOptionsKeys: CodingKey {
        case method
        case handling
        case body
        case headers
        case referrer
    }
    
    enum FetchInitBody {
        case form(NSDictionary)
        case string(String)
    }
    
    /// FetchAPI init options
    struct FetchInitOptions: Decodable {
        /// HTTP request method (default to GET). Specify in JavaScript string.
        var method: HTTPMethod
        
        /// The handling directives for the request (default to `NARequestHandlingDirective.default`). Specify in JavaScript string.
        ///
        /// Must be one of `ajax`, `browse`, or `none`. Or the fetch api will fallback to the default handling mechanism.
        var handling: NARequestHandlingDirective
        
        /// Request body. Either a string or an object in JavaScript.
        ///
        /// If the body option is an object, the body will be encoded using `application/x-www-form-urlencoded`.
        var body: Data?
        
        /// Inferred content type for the body. Cannot be specified in JavaScript.
        var bodyContentType: String?
        
        /// Overriding headers for the request.
        var headers: [String: String]?
        
        /// Referer for the request.
        ///
        /// If the referer header is specified in both `InitOptions.headers` and `InitOptions.referer`, the one in the `InitOptions.headers` will be used.
        var referer: String?
        
        init(from coder: Decoder) throws {
            let container = try coder.container(keyedBy: FetchInitOptionsKeys.self)
            
            // Request method
            let requestMethod = try? container.decodeIfPresent(String.self, forKey: .method)
            self.method = .init(rawValue: requestMethod ?? "GET")
            
            // Request handling
            let requestHandlingDirective = try? container.decodeIfPresent(String.self, forKey: .handling)?.lowercased()
            self.handling = NARequestHandlingDirective(rawValue: requestHandlingDirective ?? "") ?? .default
            
            // Referer
            self.referer = try? container.decode(String.self, forKey: .referrer)
            
            // POST body
            if let formBody = try? container.decodeIfPresent([String: String].self, forKey: .body) {
                self.body = try formEncode(formBody).data(using: .utf8, allowLossyConversion: true)
                self.bodyContentType = "application/x-www-form-urlencoded"
            } else if let stringBody = try? container.decodeIfPresent(String.self, forKey: .body) {
                self.body = stringBody.data(using: .utf8, allowLossyConversion: true)
            } else if container.contains(.body) {
                Log.error("[NineAnimatorCore.NineAnimator.FetchAPI] Failed to encode the body of the request because the type is either unknown or unsupported.")
            }
            
            // Additional headers
            self.headers = try? container.decodeIfPresent([String: String].self, forKey: .headers)
        }
        
        init() {
            method = .get
            handling = .default
        }
    }
}

// MARK: - FetchAPI.Response
@available(iOS 13, *)
private extension NACoreEngineExportsNineAnimator {
    @objc class FetchResponse: NSObject, NACoreEngineExportsResponseProtocol {
        dynamic var headers = [String: String]()
        dynamic var redirected = false
        dynamic var status = -1
        dynamic var statusText = "Unknown"
        dynamic var url = ""
        dynamic var responseData: Data?
        
        dynamic var ok: Bool {
            (200..<300).contains(status)
        }
        
        private weak var engine: NACoreEngine?
        
        init(engine: NACoreEngine) {
            self.engine = engine
            super.init()
        }
        
        func json() -> JSValue? {
            if let engine = self.engine {
                return engine.retainNativePromise(.firstly {
                    [responseData, weak engine] in
                    guard let engine = engine else {
                        return nil
                    }
                    
                    if let data = responseData {
                        let deserialized = try JSONSerialization.jsonObject(
                            with: data,
                            options: []
                        )
                        return engine.convertToJSValue(deserialized)
                    }
                    
                    return engine.undefinedValue
                })
            }
            
            return nil
        }
        
        func text() -> JSValue? {
            if let engine = self.engine {
                return engine.retainNativePromise(.firstly {
                    [responseData, weak engine] in
                    guard let engine = engine else {
                        return nil
                    }
                    
                    if let data = responseData {
                        let textResponse = String(decoding: data, as: UTF8.self)
                        return engine.convertToJSValue(textResponse)
                    }
                    
                    return engine.undefinedValue
                })
            }
            
            return nil
        }
    }
}
