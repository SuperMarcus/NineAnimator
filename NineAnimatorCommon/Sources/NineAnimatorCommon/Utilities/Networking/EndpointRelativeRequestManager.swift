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

/// NineAnimator network request manager for the sources.
open class NAEndpointRelativeRequestManager: NARequestManager {
    /// Endpoint URL retrieved from the source object
    public var endpointURL: URL? {
        _initEndpoint
    }
    
    private var _initEndpoint: URL?
    
    public init(endpoint: URL? = nil) {
        self._initEndpoint = endpoint
        super.init()
    }
    
    /// Generate a request builder with an URLConvertible
    ///
    /// - Parameters:
    ///     - query: The query items to be encoded to the url. If the url specified already contains query components, items specified by this dictionary will override the items with the same key in the url.
    public func request(_ endpointRelativePath: String, handling: NARequestHandlingDirective = .default, method: HTTPMethod = .get, query: URLQueryParameters? = nil, parameters: Parameters? = nil, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil) -> RequestBuilding {
        self.request(
            url: EndpointRelativeURLConvertible(parent: self, relativePath: endpointRelativePath),
            handling: handling,
            method: method,
            query: query,
            parameters: parameters,
            encoding: encoding,
            headers: headers
        )
    }
    
    private struct EndpointRelativeURLConvertible: URLConvertible {
        weak var parent: NAEndpointRelativeRequestManager?
        var relativePath: String
        
        func asURL() throws -> URL {
            guard let parent = parent else {
                throw NineAnimatorError.unknownError("Loosing reference to parent request manager while trying to construct a request URL.")
            }
            return try URL(
                string: relativePath,
                relativeTo: try parent.endpointURL.tryUnwrap()
            ).tryUnwrap()
        }
    }
}
