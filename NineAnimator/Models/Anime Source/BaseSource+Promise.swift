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

// Promisified request methods
extension PromiseSource where Self: BaseSource {
    /// Request a string content with URL using the browsing URLSession
    func request(browseUrl: URL,
                 query: [String: CustomStringConvertible] = [:],
                 headers: [String: String] = [:]) -> NineAnimatorPromise<String> {
        NineAnimatorPromise {
            callback in self.request(
                browse: self.assembleQuery(query, for: browseUrl),
                headers: headers,
                completion: callback
            )
        }
    }
    
    /// Request a string content with path related to endpoint using the browsing URLSession
    func request(browsePath path: String,
                 query: [String: CustomStringConvertible] = [:],
                 headers: [String: String] = [:]) -> NineAnimatorPromise<String> {
        request(browseUrl: URL(string: "\(endpoint)\(path)")!, query: query, headers: headers)
    }
    
    /// Request a string content with URL using the ajax URLSesion
    func request(ajaxUrlString: URL,
                 query: [String: CustomStringConvertible] = [:],
                 headers: [String: String] = [:]) -> NineAnimatorPromise<String> {
        NineAnimatorPromise {
            callback in self.request(
                ajaxString: self.assembleQuery(query, for: ajaxUrlString),
                headers: headers,
                completion: callback
            )
        }
    }
    
    /// Request a JSON-encoded dictionary content with URL using the ajax URLSesion
    func request(ajaxUrlDictionary: URL,
                 query: [String: CustomStringConvertible] = [:],
                 headers: [String: String] = [:]) -> NineAnimatorPromise<NSDictionary> {
        NineAnimatorPromise {
            callback in self.request(
                ajax: self.assembleQuery(query, for: ajaxUrlDictionary),
                headers: headers,
                completion: callback
            )
        }
    }
    
    /// Request a string content with path related to endpoint using the ajax URLSesion
    func request(ajaxPathString path: String,
                 query: [String: CustomStringConvertible] = [:],
                 headers: [String: String] = [:]) -> NineAnimatorPromise<String> {
        request(ajaxUrlString: URL(string: "\(endpoint)\(path)")!, headers: headers)
    }
    
    /// Request a JSON-encoded dictionary with path related to endpoint using the ajax URLSesion
    func request(ajaxPathDictionary path: String,
                 query: [String: CustomStringConvertible] = [:],
                 headers: [String: String] = [:]) -> NineAnimatorPromise<NSDictionary> {
        request(ajaxUrlDictionary: URL(string: "\(endpoint)\(path)")!, query: query, headers: headers)
    }
    
    private func assembleQuery(_ query: [String: CustomStringConvertible], for url: URL) -> URL {
        guard !query.isEmpty,
            var urlBuilder = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else { return url }
        urlBuilder.queryItems = query.map { .init(name: $0.0, value: $0.1.description) }
        return urlBuilder.url ?? url
    }
}
