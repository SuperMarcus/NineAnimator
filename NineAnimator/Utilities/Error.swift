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

import Foundation

/// A generic error class thrown within NineAnimator
class NineAnimatorError: NSError {
    class var urlError: URLError { URLError() }
    class var decodeError: DecodeError { DecodeError() }
    class var lastItemInQueueError: LastItemInQueueError { LastItemInQueueError() }
    class var unknownError: UnknownError { UnknownError() }
    
    class func decodeError(_ info: String? = nil) -> DecodeError {
        DecodeError(info)
    }
    
    class func unknownError(_ failiureReason: String) -> UnknownError {
        UnknownError(failiureReason)
    }
    
    class func responseError(_ failiureReason: String) -> ResponseError {
        ResponseError(failiureReason)
    }
    
    class func providerError(_ failiureReason: String) -> ProviderError {
        ProviderError(failiureReason)
    }
    
    class func searchError(_ failiureReason: String) -> SearchError {
        SearchError(failiureReason)
    }
    
    class func authenticationRequiredError(_ failiureReason: String, _ authenticationUrl: URL? = nil) -> AuthenticationRequiredError {
        AuthenticationRequiredError(failiureReason, authenticationUrl: authenticationUrl)
    }
    
    class func contentUnavailableError(_ failiureReason: String) -> ContentUnavailableError {
        ContentUnavailableError(failiureReason)
    }
    
    var sourceOfError: Any?
    weak var relatedRequestManager: NARequestManager?
    
    init(_ code: Int,
         message: String,
         failiureReason: String? = nil,
         userInfo: [String: Any]? = nil) {
        // At the moment, all parameters of the error is stored in the
        // userInfo dictionary
        var newUserInfo = userInfo ?? [:]
        newUserInfo["message"] = message
        newUserInfo["failiureReason"] = failiureReason
        
        // Call parent constructor
        super.init(domain: "com.marcuszhou.nineanimator.error", code: code, userInfo: newUserInfo)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // Right now, using message as localized description
    override var localizedDescription: String {
        userInfo["message"] as? String ?? super.localizedDescription
    }
    
    override var localizedFailureReason: String? {
        userInfo["failiureReason"] as? String
    }
    
    override var description: String {
        if let localizedFailureReason = localizedFailureReason {
            return "NineAnimatorError(\(code)) \(localizedDescription): \(localizedFailureReason)"
        } else { return "NineAnimatorError(\(code)) \(localizedDescription)" }
    }
    
    /// Bind the sourceOfError to this Error object
    func withSourceOfError(_ bindingErrorSource: Any) -> Self {
        sourceOfError = bindingErrorSource
        return self
    }
}

// MARK: - NineAnimator Errors
extension NineAnimatorError {
    /// Representing an unexpexted or unclassified error that had occurred
    /// within NineAnimator
    class UnknownError: NineAnimatorError {
        init(_ failiureReason: String = "Unknown reason", userInfo: [String: Any]? = nil) {
            super.init(0,
                       message: "An unknown error had occurred",
                       failiureReason: failiureReason,
                       userInfo: userInfo)
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
    
    /// Representing an error which NineAnimator cannot understand an URL
    /// or cannot decode/encode the URL.
    class URLError: NineAnimatorError {
        init(userInfo: [String: Any]? = nil) {
            super.init(1, message: "There is something wrong with the url", userInfo: userInfo)
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
    
    /// Representing an error which NineAnimator cannot understand a response
    /// sent by the server.
    class ResponseError: NineAnimatorError {
        init(_ failiureReason: String, userInfo: [String: Any]? = nil) {
            super.init(2,
                       message: "NineAnimator cannot understand a response sent by the server",
                       failiureReason: failiureReason,
                       userInfo: userInfo)
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
    
    /// Representing an error which NineAnimator cannot fetch a resource on
    /// the streaming server.
    ///
    /// This error is differentiated with the response by the source of the
    /// error. ResponseError is generally thrown by the Source and provider
    /// error is generally thrown by the ProviderParser. In the future the
    /// two errors may be merged into one.
    class ProviderError: NineAnimatorError {
        init(_ failiureReason: String, userInfo: [String: Any]? = nil) {
            super.init(3,
                       message: "NineAnimator cannot fetch a resource on the streaming server",
                       failiureReason: failiureReason,
                       userInfo: userInfo)
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
    
    /// A search error represents a non-fatal error thrown by the Source
    /// when searching.
    ///
    /// For example, "no results" count as a search error.
    class SearchError: NineAnimatorError {
        init(_ failiureReason: String, userInfo: [String: Any]? = nil) {
            super.init(4,
                       message: "Search Completed",
                       failiureReason: failiureReason,
                       userInfo: userInfo)
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
    
    /// Representing an error which NineAnimator cannot continute until
    /// an authentication action is performed.
    ///
    /// Typically NineAnimator will request the user to intervene when
    /// this error is thrown, and then continute to perform the
    /// operation after the user has completed the authentication.
    class AuthenticationRequiredError: NineAnimatorError {
        init(_ failiureReason: String, authenticationUrl: URL?, userInfo: [String: Any]? = nil) {
            // Reconstruct the userInfo with authentication url included
            var newUserInfo = userInfo ?? [:]
            newUserInfo["authenticationUrl"] = authenticationUrl
            
            // Call the parent constructor
            super.init(5,
                       message: "An authentication is required before NineAnimator can continue",
                       failiureReason: failiureReason,
                       userInfo: newUserInfo)
        }
        
        /// The url at which an authentication can be attempted
        var authenticationUrl: URL? {
            userInfo["authenticationUrl"] as? URL
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
        
        override var localizedRecoverySuggestion: String? {
            // If the recovery url exists
            if userInfo["authenticationUrl"] is URL {
                return "You may perform the authentication with the opening link, after which NineAnimator may re-attempt the request."
            }
            
            return nil
        }
        
        override var localizedRecoveryOptions: [String]? {
            if userInfo["authenticationUrl"] is URL {
                return [ "Open Link" ]
            }
            
            return nil
        }
    }
    
    /// Representing an error which NineAnimator cannot decode a
    /// previously persisted file or self-generated data.
    class DecodeError: NineAnimatorError {
        init(_ info: String? = nil, userInfo: [String: Any]? = nil) {
            let message: String
            if let info = info {
                message = "A required value (\(info)) cannot be read"
            } else { message = "A required value cannot be read" }
            super.init(6, message: message, userInfo: userInfo)
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
    
    /// Representing an error which either the current item is the last
    /// item in a list or there are no elements in the list.
    class LastItemInQueueError: NineAnimatorError {
        init(userInfo: [String: Any]? = nil) {
            super.init(7, message: "There are no more items in the selected list", userInfo: userInfo)
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
    
    /// An WAF authentication challenge is present and can be automatically
    /// completed by NineAnimator
    class CloudflareAuthenticationChallenge: AuthenticationRequiredError {
        /// The resolved authentication response
        var authenticationResponse: [String: String]? {
            userInfo["cloudflare_answer"] as? [String: String]
        }
        
        init(authenticationUrl: URL?, responseParameters: [String: String]?) {
            var userInfo = [String: Any]()
            
            if let parameters = responseParameters {
                userInfo["cloudflare_answer"] = parameters
            }
            
            super.init(
                "This website requests NineAnimator to verify your identity",
                authenticationUrl: authenticationUrl,
                userInfo: userInfo
            )
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
    
    /// Representing a content or service that is no longer available.
    class ContentUnavailableError: NineAnimatorError {
        init(_ reason: String, userInfo: [String: Any]? = nil) {
            super.init(8, message: "This content is no longer available", failiureReason: reason, userInfo: userInfo)
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
    
    /// Representing that an episode is not available on the specified server. Optionally
    /// providing a list of alternative `EpisodeLink`.
    class EpisodeServerNotAvailableError: ContentUnavailableError {
        /// A list of alternative episodes that are available for streaming
        var alternativeEpisodes: [EpisodeLink]? {
            userInfo["alternative_episodes"] as? [EpisodeLink]
        }
        
        /// An updated server map that includes the human readable name for the alternative episodes
        var updatedServerMap: [Anime.ServerIdentifier: String]? {
            userInfo["alternative_server_map"] as? [Anime.ServerIdentifier: String]
        }
        
        init(unavailableEpisode: EpisodeLink,
             alternativeEpisodes: [EpisodeLink]? = nil,
             updatedServerMap: [Anime.ServerIdentifier: String]? = nil,
             userInfo: [String: Any]? = nil) {
            var updatingUserInfo = userInfo ?? [:]
            let unavailableServerName = updatedServerMap?[unavailableEpisode.server]
            
            if let alternativeEpisodes = alternativeEpisodes {
                updatingUserInfo["alternative_episodes"] = alternativeEpisodes
            }
            
            if let updatedServerMap = updatedServerMap {
                updatingUserInfo["alternative_server_map"] = updatedServerMap
            }
            
            super.init(
                "This episode is not available on \(unavailableServerName ?? "the selected server").",
                userInfo: updatingUserInfo
            )
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
    
    /// An error received from the NineAnimatorCloud service
    class NineAnimatorCloudError: NineAnimatorError {
        var statusCode: Int? {
            userInfo["statusCode"] as? Int
        }
        
        init(statusCode: Int, message: String) {
            super.init(9, message: "NineAnimatorCloud service responded with an error", failiureReason: message, userInfo: [
                "statusCode": statusCode
            ])
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
}
