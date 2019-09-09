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

class Simkl: BaseListingService, ListingService {
    var name: String { return "Simkl" }
    
    /// Simkl API endpoint
    let endpoint = URL(string: "https://api.simkl.com")!
    
    var cachedReferenceEpisodes = [String: [SimklEpisodeEntry]]()
    
    var cachedCollections: [String: Collection]?
    
    var mutationQueues = [NineAnimatorAsyncTask]()
    
    override var identifier: String {
        return "com.marcuszhou.nineanimator.service.simkl"
    }
    
    required init(_ parent: NineAnimator) {
        super.init(parent)
    }
    
    func resetCollectionsCache() {
        cachedCollections = nil
    }
}

// MARK: - Capabilities
extension Simkl {
    var isCapableOfListingAnimeInformation: Bool { return false }
    
    var isCapableOfPersistingAnimeState: Bool { return didSetup }
    
    var isCapableOfRetrievingAnimeState: Bool { return didSetup }
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
        get { return persistedProperties["code"] as? String }
        set { persistedProperties["code"] = newValue }
    }
    
    private var accessToken: String? {
        get { return persistedProperties["access_token"] as? String }
        set { persistedProperties["access_token"] = newValue }
    }
    
    /// The Single-Sign-On URL for Simkl
    var ssoUrl: URL {
        return URL(string: "https://simkl.com/oauth/authorize?response_type=code&client_id=\(clientId)&redirect_uri=https%3A%2F%2Fnineanimator-api.marcuszhou.com%2Fapi%2Flink_simkl%2Fauthorize")!
    }
    
    /// Single-Sign-On Callback Scheme
    var ssoCallbackScheme: String { return "nineanimator-list-auth" }
    
    /// NineAnimator Simkl Client Identifier
    var clientId: String {
        return "d90575da9e8e76005f9148b981885c4f051dbb2634ccb67cca01f87bcbeb1ecf"
    }
    
    var didSetup: Bool { return accessToken != nil && code != nil }
    
    /// Remove user credentials
    func deauthenticate() {
        Log.info("[Simkl] Removing credentials")
        code = nil
        accessToken = nil
    }
    
    /// Authenticate the user with the redirecting url
    func authenticate(withUrl url: URL) -> Error? {
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
