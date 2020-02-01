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

class Kitsu: BaseListingService, ListingService {
    var name: String { "Kitsu.io" }
    
    /// Anilist API endpoint
    let endpoint = URL(string: "https://kitsu.io/api/edge")!
    
    var _cachedUser: User?
    var _mutationTaskPool = [NineAnimatorAsyncTask]()
    
    override var identifier: String {
        "com.marcuszhou.nineanimator.service.kitsu"
    }
    
    required init(_ parent: NineAnimator) {
        super.init(parent)
    }
}

extension Kitsu {
    var isCapableOfListingAnimeInformation: Bool {
        false
    }
    
    var isCapableOfPersistingAnimeState: Bool {
        didSetup
    }
    
    var isCapableOfRetrievingAnimeState: Bool {
        didSetup
    }
}

// MARK: - Authentication
extension Kitsu {
    private var accessToken: String? {
        get { persistedProperties["access_token"] as? String }
        set { persistedProperties["access_token"] = newValue }
    }
    
    private var refreshToken: String? {
        get { persistedProperties["refresh_token"] as? String }
        set { persistedProperties["refresh_token"] = newValue }
    }
    
    private var accessTokenExpirationDate: Date {
        get { (persistedProperties["access_token_expiration"] as? Date) ?? .distantPast }
        set { persistedProperties["access_token_expiration"] = newValue }
    }
    
    var oauthUrl: URL { URL(string: "https://kitsu.io/api/oauth/token")! }
    
    var didSetup: Bool { accessToken != nil && refreshToken != nil }
    
    var didExpire: Bool { accessTokenExpirationDate.timeIntervalSinceNow < 0 }
    
    // swiftlint:disable closure_end_indentation
    func authenticate(user: String, password: String) -> NineAnimatorPromise<Void> {
        NineAnimatorPromise.firstly {
            () -> Data? in
            var queryBuilder = URLComponents()
            queryBuilder.queryItems = [
                .init(name: "grant_type", value: "password"),
                .init(name: "username", value: user),
                .init(name: "password", value: password)
            ]
            return queryBuilder.percentEncodedQuery?.data(using: .utf8)
        } .thenPromise {
            [weak self, oauthUrl] in
            self?.request(
                oauthUrl,
                method: .post,
                data: $0
            )
        } .then(onAuthenticationResponse)
    }
    // swiftlint:enable closure_end_indentation
    
    /// Re-authenticate an expired session with the refresh token
    private func reauthenticate() -> NineAnimatorPromise<Void> {
        NineAnimatorPromise.firstly {
            () -> Data? in
            guard let refreshToken = self.refreshToken else {
                throw NineAnimatorError.authenticationRequiredError("Cannot refresh an unauthenticated session")
            }
            return try formEncode([
                "grant_type": "refresh_token",
                "refresh_token": refreshToken
            ]).data(using: .utf8)
        } .thenPromise {
            self.request(
                self.oauthUrl,
                method: .post,
                data: $0
            )
        } .then(onAuthenticationResponse)
    }
    
    /// Reauthenticate the session if it is setup and expired
    func reauthenticateIfNeeded() -> NineAnimatorPromise<Void> {
        didSetup && didExpire ? reauthenticate() : .success(())
    }
    
    /// Handles the authentication responses
    private func onAuthenticationResponse(_ responseData: Data) throws {
        let response = try (JSONSerialization.jsonObject(
            with: responseData,
            options: []) as? NSDictionary
        ).tryUnwrap(.responseError("Server sent an invalid response"))
        
        // If the error entry is present and an error message is provided
        if response["error"] is String, let errorMessage = response.valueIfPresent(
                at: "error_description",
                type: String.self
            ) {
            throw NineAnimatorError.authenticationRequiredError(errorMessage, nil)
        }
        
        // Retrieve the token from the json response
        let token = try response.value(at: "access_token", type: String.self)
        let refreshToken = try response.value(at: "refresh_token", type: String.self)
        let tokenType = try response.value(at: "token_type", type: String.self)
        let expiration = try response.value(at: "expires_in", type: Int.self)
        
        // Check token type
        guard tokenType == "Bearer" else {
            throw NineAnimatorError.responseError("Unsupported token type: \(tokenType)")
        }
        
        // Store tokens
        self.authenticate(
            token: token,
            refreshToken: refreshToken,
            until: Date().addingTimeInterval(TimeInterval(expiration))
        )
    }
    
    /// Store credentials
    private func authenticate(token: String, refreshToken: String, until expirationDate: Date) {
        Log.info("[Kitsu.io] Authenticated until %@", expirationDate)
        self.accessToken = token
        self.refreshToken = refreshToken
        self.accessTokenExpirationDate = expirationDate
    }
    
    /// Remove credentials
    func deauthenticate() {
        Log.info("[Kitsu.io] Removing credentials")
        accessToken = nil
        refreshToken = nil
        accessTokenExpirationDate = Date.distantPast
        _cachedUser = nil
    }
}

// MARK: - Request helper
extension Kitsu {
    /// Representing a standard JSON: API data object
    struct APIObject {
        let identifier: String
        let type: String
        let attributes: [String: Any]
        let includedRelations: [String: APIObject]
        
        let raw: NSDictionary
        
        init(_ raw: NSDictionary, allIncluded: [APIObject] = []) throws {
            self.raw = raw
            identifier = try raw.value(at: "id", type: String.self)
            type = try raw.value(at: "type", type: String.self)
            attributes = try raw.value(at: "attributes", type: [String: Any].self)
            
            if let relations = raw["relationships"] as? [String: NSDictionary] {
                includedRelations = Dictionary(
                    uniqueKeysWithValues: relations.compactMap {
                        relation -> (String, APIObject)? in
                        if let dataId = relation.value.value(forKeyPath: "data.id") as? String,
                            let includedRelation = allIncluded.first(where: { $0.identifier == dataId }) {
                            return (relation.key, includedRelation)
                        }
                        return nil
                    }
                )
            } else { includedRelations = [:] }
        }
    }
    
    func apiRequest(_ path: String, query: [String: String] = [:], body: [String: Any] = [:], method: HTTPMethod = .get) -> NineAnimatorPromise<[APIObject]> {
        reauthenticateIfNeeded().then {
            [endpoint, unowned self] in // First and foremost, build the request URL
            // Headers for JSON: API
            var headers = [
                "Accept": "application/vnd.api+json",
                "Content-Type": "application/vnd.api+json"
            ]
            
            // Add oauth token to headers
            if let token = self.accessToken {
                headers["Authorization"] = "Bearer \(token)"
            }
            
            // Encode body data
            var bodyData: Data?
            if !body.isEmpty {
                bodyData = try? JSONSerialization.data(withJSONObject: body, options: [])
            }
            
            var requestingUrl = endpoint.appendingPathComponent(path)
            
            // Encode query parameters
            if !query.isEmpty {
                guard var urlBuilder = URLComponents(url: requestingUrl, resolvingAgainstBaseURL: false) else {
                    throw NineAnimatorError.urlError
                }
                
                // Assign query items
                urlBuilder.queryItems = query.map {
                    URLQueryItem(name: $0.key, value: $0.value)
                }
                
                requestingUrl = try urlBuilder.url.tryUnwrap()
            }
            
            // Generate request url
            return (
                requestingUrl,
                bodyData,
                headers
            )
        } .thenPromise {
            [unowned self] url, bodyData, headers in // Then request
            self.request(url, method: method, data: bodyData, headers: headers)
        } .then {
            data -> NSDictionary in
            try some(
                (try JSONSerialization.jsonObject(with: data, options: [])) as? NSDictionary,
                or: NineAnimatorError.decodeError
            )
        } .then {
            responseDictionary in
            // Retreive data section as a collection
            let dataSection: [NSDictionary]
            if let dataSectionCollection = responseDictionary["data"] as? [NSDictionary] {
                dataSection = dataSectionCollection
            } else if let dataSectionResource = responseDictionary["data"] as? NSDictionary {
                dataSection = [ dataSectionResource ]
            } else { throw NineAnimatorError.decodeError }
            
            // First, parse the included section of the response
            let includedSection = try (responseDictionary["included"] as? [NSDictionary])?.compactMap { try APIObject($0) } ?? []
            
            // Then, parse the data section
            return try dataSection.map { try APIObject($0, allIncluded: includedSection) }
        }
    }
}
