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

/// The encoder used to encode query parameters
public protocol URLQueryParameterEncoding {
    func encode(key: String, value: CustomStringConvertible) throws -> URLQueryItem
}

/// An encoder for query parameters that conforms to the w3c recommendations
public struct URLQueryParameterW3CEncoding: URLQueryParameterEncoding {
    public func encode(key: String, value: CustomStringConvertible) throws -> URLQueryItem {
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove("+")
        
        func encode(item: String) -> String {
            (item.addingPercentEncoding(
                withAllowedCharacters: allowedCharacters
            ) ?? "").replacingOccurrences(of: "%20", with: "+")
        }
        
        return .init(
            name: encode(item: key),
            value: encode(item: value.description)
        )
    }
}

/// URL query parameters in a order-preserving manner
public struct URLQueryParameters: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = CustomStringConvertible
    
    public var values: [(name: String, value: CustomStringConvertible)]
    public var encoding: URLQueryParameterEncoding = URLQueryParameterW3CEncoding()
    
    public init(dictionaryLiteral elements: (String, CustomStringConvertible)...) {
        self.values = elements
    }
    
    public func appendTo(request: inout URLRequest) throws {
        var urlBuilder = try URLComponents(
            url: try request.url.tryUnwrap(),
            resolvingAgainstBaseURL: true
        ).tryUnwrap()
        urlBuilder.percentEncodedQueryItems = try self.values.reduce(
            into: urlBuilder.percentEncodedQueryItems ?? []
        ) {
            items, currentItem in items.append(
                try self.encoding.encode(
                    key: currentItem.name,
                    value: currentItem.value
                )
            )
        }
        request.url = try urlBuilder.url.tryUnwrap()
    }
}
