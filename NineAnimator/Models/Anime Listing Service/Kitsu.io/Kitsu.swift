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

class Kitsu: BaseListingService, ListingService {
    var name: String { return "Kitsu.io" }
    
    /// Anilist API endpoint
    let endpoint = URL(string: "https://kitsu.io/api/edge")!
    
    var _cachedUser: User?
    
    override var identifier: String {
        return "com.marcuszhou.nineanimator.service.kitsu"
    }
    
    required init(_ parent: NineAnimator) {
        super.init(parent)
    }
}

extension Kitsu {
    var isCapableOfListingAnimeInformation: Bool {
        return false
    }
    
    var isCapableOfPersistingAnimeState: Bool {
        return didSetup && !didExpire
    }
    
    var isCapableOfRetrievingAnimeState: Bool {
        return didSetup && !didExpire
    }
}

// MARK: - Authentication
extension Kitsu {
    private var accessToken: String? {
        get { return persistedProperties["access_token"] as? String }
        set { persistedProperties["access_token"] = newValue }
    }
    
    private var accessTokenExpirationDate: Date {
        get { return (persistedProperties["access_token_expiration"] as? Date) ?? .distantPast }
        set { return persistedProperties["access_token_expiration"] = newValue }
    }
    
    var oauthUrl: URL { return URL(string: "https://kitsu.io/api/oauth/token")! }
    
    var didSetup: Bool { return accessToken != nil }
    
    var didExpire: Bool { return accessTokenExpirationDate.timeIntervalSinceNow < 0 }
    
    // swiftlint:disable closure_end_indentation
    func authenticate(user: String, password: String) -> NineAnimatorPromise<Void> {
        return NineAnimatorPromise.firstly {
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
        } .then {
            try JSONSerialization.jsonObject(with: $0, options: []) as? NSDictionary
        } .then {
            [weak self] response in
            guard let self = self else { return nil }
            
            // Retrieve the token from the json response
            guard let token = response["access_token"] as? String,
                let tokenType = response["token_type"] as? String,
                let expiration = response["expires_in"] as? Int else {
                if let errorMessage = response["error_description"] as? String {
                    throw NineAnimatorError.authenticationRequiredError(errorMessage, nil)
                }
                throw NineAnimatorError.unknownError
            }
            
            // Check token type
            guard tokenType == "Bearer" else {
                throw NineAnimatorError.responseError("Unsupported token type: \(tokenType)")
            }
            
            // Store tokens
            self.authenticate(token: token, until: Date().addingTimeInterval(TimeInterval(expiration)))
            
            return ()
        }
    }
    // swiftlint:enable closure_end_indentation
    
    private func authenticate(token: String, until expirationDate: Date) {
        Log.info("[Kitsu.io] Authenticated until %@", expirationDate)
        self.accessToken = token
        self.accessTokenExpirationDate = expirationDate
    }
    
    func deauthenticate() {
        Log.info("[Kitsu.io] Removing credentials")
        accessToken = nil
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
    
    func apiRequest(_ path: String, query: [String: String]) -> NineAnimatorPromise<[APIObject]> {
        // Headers for JSON: API
        var headers = [
            "Accept": "application/vnd.api+json",
            "Content-Type": "application/vnd.api+json"
        ]
        
        // Add oauth token to headers
        if let token = accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        return NineAnimatorPromise.firstly {
            [endpoint] in // First and foremost, build the request URL
            guard var urlBuilder = URLComponents(url: endpoint.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
                throw NineAnimatorError.urlError
            }
            
            // Assign query items
            urlBuilder.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            
            // Generate request url
            return try some(urlBuilder.url, or: NineAnimatorError.urlError)
        } .thenPromise {
            [unowned self] in // Then request
            self.request($0, method: .get, data: nil, headers: headers)
        } .then {
            try some(
                (try JSONSerialization.jsonObject(with: $0, options: [])) as? NSDictionary,
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
