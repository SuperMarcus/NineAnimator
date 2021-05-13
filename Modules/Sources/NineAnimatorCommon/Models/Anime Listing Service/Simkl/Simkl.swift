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

public class Simkl: BaseListingService, ListingService {
    public var name: String { "Simkl" }
    
    /// Simkl API endpoint
    public let endpoint = URL(string: "https://api.simkl.com")!
    
    internal var cachedReferenceEpisodes = [String: [SimklEpisodeEntry]]()
    
    internal var mutationQueues = [NineAnimatorAsyncTask]()
    
    override public var identifier: String {
        "com.marcuszhou.nineanimator.service.simkl"
    }
    
    required public init(_ parent: NineAnimator) {
        super.init(parent)
    }
}

// MARK: - Capabilities
public extension Simkl {
    var isCapableOfListingAnimeInformation: Bool { false }
    
    var isCapableOfPersistingAnimeState: Bool { didSetup }
    
    var isCapableOfRetrievingAnimeState: Bool { didSetup }
}

// MARK: - Request helpers
extension Simkl {
    func apiRequest<ResponseType>(
        _ path: String,
        query: [String: CustomStringConvertible] = [:],
        body: Data? = nil,
        headers: HTTPHeaders = [:],
        method: HTTPMethod = .get,
        expectedResponseType: ResponseType.Type
    ) -> NineAnimatorPromise<ResponseType> {
        let requestingBaseUrl = endpoint.appendingPathComponent(path)
        var modifiedHeaders = headers
        
        // Add identifying headers
        modifiedHeaders["simkl-api-key"] = clientId
        
        if let accessToken = accessToken {
            modifiedHeaders["Authorization"] = "Bearer \(accessToken)"
        }
        
        // Assemble the url and then make the request
        return NineAnimatorPromise.firstly {
            var components = URLComponents(url: requestingBaseUrl, resolvingAgainstBaseURL: true)
            components?.queryItems = query.map { .init(name: $0.key, value: $0.value.description) }
            return components?.url
        } .thenPromise {
            self.request(
                $0,
                method: method,
                data: body,
                headers: modifiedHeaders
            )
        } .then {
            try JSONSerialization.jsonObject(with: $0, options: []) as? ResponseType
        }
    }
}

// MARK: - Authentications
extension Simkl {
    private var code: String? {
        get { persistedProperties[PersistedKeys.authorizationCode] as? String }
        set { persistedProperties[PersistedKeys.authorizationCode] = newValue }
    }
    
    private var accessToken: String? {
        get { persistedProperties[PersistedKeys.accessToken] as? String }
        set { persistedProperties[PersistedKeys.accessToken] = newValue }
    }
    
    /// The Single-Sign-On URL for Simkl
    public var ssoUrl: URL {
        URL(string: "https://simkl.com/oauth/authorize?response_type=code&client_id=\(clientId)&redirect_uri=https%3A%2F%2Fnineanimator-api.marcuszhou.com%2Fapi%2Flink_simkl%2Fauthorize")!
    }
    
    /// Single-Sign-On Callback Scheme
    public var ssoCallbackScheme: String { "nineanimator-list-auth" }
    
    /// NineAnimator Simkl Client Identifier
    public var clientId: String {
        "d90575da9e8e76005f9148b981885c4f051dbb2634ccb67cca01f87bcbeb1ecf"
    }
    
    public var didSetup: Bool { accessToken != nil && code != nil }
    
    /// Remove user credentials
    public func deauthenticate() {
        Log.info("[Simkl] Removing credentials and data")
        code = nil
        accessToken = nil
        resetCollectionsCache()
    }
    
    /// Authenticate the user with the redirecting url
    public func authenticate(withUrl url: URL) -> Error? {
        do {
            // Decode authentication parameters from query
            let authParams = try formDecode(url.query ?? "")
            guard authParams["token_type"] == "bearer" else { throw NineAnimatorError.responseError("Unknown token type") }
            
            // Store the credentials to the persistence store
            code = try authParams["code"].tryUnwrap(.responseError("The server did not return an authorization code"))
            accessToken = try authParams["access_token"].tryUnwrap(.responseError("The server returned an invalid access token"))
            
            Log.info("[Simkl] Credentials accepted")
        } catch { return error }
        return nil
    }
}
