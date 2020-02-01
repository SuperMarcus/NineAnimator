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

class MyAnimeList: BaseListingService, ListingService {
    var name: String { "MyAnimeList.net" }
    
    override var identifier: String { "com.marcuszhou.nineanimator.service.mal" }
    
    /// MAL api endpoint
    let endpoint = URL(string: "https://api.myanimelist.net/v0.21")!
    
    var _mutationTaskPool = [NineAnimatorAsyncTask]()
    
    lazy var _allCollections: [Collection] = [
        ("watching", "Currently Watching"),
        ("plan_to_watch", "Plan to Watch"),
        ("completed", "Completed"),
        ("on_hold", "On Hold"),
        ("dropped", "Dropped")
    ] .map { Collection(self, key: $0.0, title: $0.1) }
    
    override func onRegister() {
        super.onRegister()
        
        parent.register(additionalRecommendationSource: SeasonalAnimeRecommendation(self))
        parent.register(additionalRecommendationSource: TrendingAnimeRecommendation(self))
    }
}

// MARK: - Capabilities
extension MyAnimeList {
    var isCapableOfListingAnimeInformation: Bool { true }
    
    var isCapableOfPersistingAnimeState: Bool { didSetup }
    
    var isCapableOfRetrievingAnimeState: Bool { didSetup }
}

// MARK: - Authentications
extension MyAnimeList {
    private var accessToken: String? {
        get { persistedProperties["access_token"] as? String }
        set { persistedProperties["access_token"] = newValue }
    }
    
    private var accessTokenExpirationDate: Date {
        get { (persistedProperties["access_token_expiration"] as? Date) ?? .distantPast }
        set { persistedProperties["access_token_expiration"] = newValue }
    }
    
    private var refreshToken: String? {
        get { persistedProperties["restore_token"] as? String }
        set { persistedProperties["restore_token"] = newValue }
    }
    
    /// MAL Android app's client identifier
    private var clientIdentifier: String { "6114d00ca681b7701d1e15fe11a4987e" }
    
    var didSetup: Bool { accessToken != nil }
    
    var didExpire: Bool { accessTokenExpirationDate.timeIntervalSinceNow < 0 }
    
    func deauthenticate() {
        Log.info("[MyAnimeList] Removing credentials")
        accessToken = nil
        refreshToken = nil
        accessTokenExpirationDate = .distantPast
    }
    
    /// Authenticate the session with username and password
    func authenticate(withUser user: String, password: String) -> NineAnimatorPromise<Void> {
        NineAnimatorPromise.firstly {
            [clientIdentifier] in
            var formBuilder = URLComponents()
            formBuilder.queryItems = [
                .init(name: "client_id", value: clientIdentifier),
                .init(name: "grant_type", value: "password"),
                .init(name: "password", value: password),
                .init(name: "username", value: user)
            ]
            return try some(formBuilder.percentEncodedQuery?.data(using: .utf8), or: .urlError)
        } .thenPromise {
            [endpoint] encodedForm in
            // Send refresh request with refresh token
            self.request(endpoint.appendingPathComponent("/auth/token"), method: .post, data: encodedForm, headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "application/json",
                "Content-Length": String(encodedForm.count)
            ])
        } .then {
            (responseData: Data) in
            try JSONSerialization.jsonObject(with: responseData, options: []) as? NSDictionary
        } .thenPromise { self.authenticate(withResponseObject: $0) }
    }
    
    /// Refresh the expired token with the stored refresh token
    private func authenticateWithRefreshToken() -> NineAnimatorPromise<Void> {
        NineAnimatorPromise.firstly {
            self.refreshToken // Retrieve the refresh token
        } .thenPromise {
            [clientIdentifier] token in
            let encodedForm: Data = try {
                var formBuilder = URLComponents()
                formBuilder.queryItems = [
                    .init(name: "client_id", value: clientIdentifier),
                    .init(name: "grant_type", value: "refresh_token"),
                    .init(name: "refresh_token", value: token)
                ]
                return try some(formBuilder.percentEncodedQuery?.data(using: .utf8), or: .urlError)
            }()
            
            Log.info("[MyAnimeList] Re-authenticating the session with refresh token")
            
            // Send refresh request with refresh token
            return self.request(URL(string: "https://myanimelist.net/v1/oauth2/token")!, method: .post, data: encodedForm, headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "application/json",
                "Content-Length": String(encodedForm.count)
            ])
        } .then {
            (responseData: Data) in
            try JSONSerialization.jsonObject(with: responseData, options: []) as? NSDictionary
        } .thenPromise { self.authenticate(withResponseObject: $0) }
    }
    
    /// Authenticate the session with the response from MyAnimeList
    private func authenticate(withResponseObject responseObject: NSDictionary) -> NineAnimatorPromise<Void> {
        .firstly {
            // If the error entry is present in the response object
            if let error = responseObject["error"] as? String,
                let message = responseObject["message"] as? String {
                if error == "invalid_grant" { // Invalid credentials
                    throw NineAnimatorError.authenticationRequiredError(message, nil)
                } else { throw NineAnimatorError.responseError(message) }
            }
            
            let token = try some(responseObject["access_token"] as? String, or: .decodeError)
            let expirationAfter = try some(responseObject["expires_in"] as? Int, or: .decodeError)
            let refreshToken = try some(responseObject["refresh_token"] as? String, or: .decodeError)
            let tokenType = try some(responseObject["token_type"] as? String, or: .decodeError)
            
            // Check token type
            guard tokenType == "Bearer" else {
                throw NineAnimatorError.responseError("The server returned an invalid token type")
            }
            
            // Store tokens
            self.accessToken = token
            self.refreshToken = refreshToken
            self.accessTokenExpirationDate = Date().addingTimeInterval(TimeInterval(expirationAfter))
            
            Log.info("[MyAnimeList] Session authenticated")
            
            // Return success
            return ()
        }
    }
}

// MARK: - Request Helper
extension MyAnimeList {
    struct APIResponse {
        /// Access the raw response object
        let raw: NSDictionary
        
        /// Data section of the response object
        ///
        /// If no data section is found, the raw response
        /// is placed as the first element
        let data: [NSDictionary]
        
        // Paging
        let nextPageOffset: Int?
        let currentPageLimit: Int?
        
        init(_ raw: NSDictionary) throws {
            self.raw = raw
            
            // Store the data section
            if let dataSection = raw["data"] as? [NSDictionary] {
                data = dataSection
            } else { data = [ raw ] }
            
            // Parse paging section
            if let pagingSection = raw["paging"] as? NSDictionary,
                let nextPageUrlString = pagingSection["next"] as? String,
                let nextPageUrlComponents = URLComponents(string: nextPageUrlString),
                let queryItems = nextPageUrlComponents.queryItems {
                // tmp values
                var nextPageOffset: Int?
                var currentPageLimit: Int?
                
                // Interate through query items
                for queryItem in queryItems {
                    // Next page offset
                    if queryItem.name == "offset",
                        let offsetString = queryItem.value,
                        let offset = Int(offsetString) {
                        nextPageOffset = offset
                    }
                    
                    // Page limit
                    if queryItem.name == "limit",
                        let limitString = queryItem.value,
                        let limit = Int(limitString) {
                        currentPageLimit = limit
                    }
                }
                
                // Store the values
                self.nextPageOffset = nextPageOffset
                self.currentPageLimit = currentPageLimit
            } else { // Set the paging values to nil if none
                nextPageOffset = nil
                currentPageLimit = nil
            }
        }
    }
    
    func apiRequest(_ path: String, query: [String: CustomStringConvertible] = [:], body: [String: CustomStringConvertible] = [:], method: HTTPMethod = .get) -> NineAnimatorPromise<APIResponse> {
        var firstPromise: NineAnimatorPromise<Void> = .success(())
        if didSetup && didExpire {
            // Refresh the token first if needed
            firstPromise = authenticateWithRefreshToken()
        }
        return firstPromise.then {
            [endpoint, clientIdentifier, weak self] () -> (URL, [String: String], Data?) in
            var url = endpoint.appendingPathComponent(path)
            var headers = [ "X-MAL-Client-ID": clientIdentifier ]
            var encodedBodyContent: Data?
            
            // Build GET parameters
            if !query.isEmpty,
                var urlBuilder = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                urlBuilder.queryItems = query.map { .init(name: $0.key, value: $0.value.description) }
                url = try some(
                    urlBuilder.url,
                    or: .urlError
                )
            }
            
            // Add authorization header
            if let token = self?.accessToken {
                headers["Authorization"] = "Bearer \(token)"
            }
            
            // Encode content type and content length
            if !body.isEmpty {
                // Encode the content
                encodedBodyContent = try {
                    var formBuilder = URLComponents()
                    formBuilder.queryItems = body.map {
                        .init(name: $0.key, value: $0.value.description)
                    }
                    return try some(formBuilder.percentEncodedQuery?.data(using: .utf8), or: .unknownError)
                }()
                
                // Update headers
                headers["Content-Type"] = "application/x-www-form-urlencoded; charset=utf-8"
                headers["Content-Length"] = String(encodedBodyContent!.count)
            }
            
            // Return the request parameters
            return (url, headers, encodedBodyContent)
        } .thenPromise {
            url, headers, body in self.request(url, method: method, data: body, headers: headers)
        } .then {
            try JSONSerialization.jsonObject(with: $0, options: []) as? NSDictionary
        } .then {
            response in
            // If an error is reported
            if response["error"] != nil,
                let errorMessage = response["message"] as? String {
                throw NineAnimatorError.responseError(errorMessage)
            }
            
            // Construct the APIResponse
            return try APIResponse(response)
        }
    }
}
