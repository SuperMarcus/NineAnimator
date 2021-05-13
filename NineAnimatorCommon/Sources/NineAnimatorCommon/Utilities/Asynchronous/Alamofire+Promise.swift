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

// Making all `DataRequest`s conforming to the `NineAnimatorAsyncTask` protocol
extension Alamofire.DataRequest: NineAnimatorAsyncTask {
    public func cancel() {
        _ = super.cancel()
    }
}

/// A network request helper that construct `NineAnimatorPromise` for Alamofire network requests
public struct AsyncRequestHelper {
    private let initRequest: () throws -> Alamofire.DataRequest
    
    public init(_ initRequest: @escaping @autoclosure () throws -> Alamofire.DataRequest) {
        self.initRequest = initRequest
    }
    
    /// Construct a `NineAnimatorPromise` for the current request that resolves to a JSON decoable type
    public func decodableResponse<T: Decodable>(_ type: T.Type) -> NineAnimatorPromise<T> {
        dataResponse().then { try JSONDecoder().decode(T.self, from: $0) }
    }
    
    /// Construct a `NineAnimatorPromise` for the current request
    public func dataResponse() -> NineAnimatorPromise<Data> {
        NineAnimatorPromise {
            [initRequest] cb in AsyncRequestHelper.pipeError(cb) {
                try initRequest().responseData(
                    completionHandler: AsyncRequestHelper.handler(cb)
                )
            }
        }
    }
    
    /// Construct a `NineAnimatorPromise` for the current request that resolves to a `String`
    public func stringResponse() -> NineAnimatorPromise<String> {
        NineAnimatorPromise {
            [initRequest] cb in AsyncRequestHelper.pipeError(cb) {
                try initRequest().responseString(
                    completionHandler: AsyncRequestHelper.handler(cb)
                )
            }
        }
    }
    
    /// Construct a `NineAnimatorPromise` for the current request that expects and parses a JSON response
    public func jsonResponse() -> NineAnimatorPromise<Any> {
        NineAnimatorPromise {
            [initRequest] cb in AsyncRequestHelper.pipeError(cb) {
                try initRequest().responseJSON(
                    completionHandler: AsyncRequestHelper.handler(cb)
                )
            }
        }
    }
    
    private static func handler<T>(_ callback: @escaping NineAnimatorCallback<T>) -> (AFDataResponse<T>) -> Void {
        let block: (AFDataResponse<T>) -> Void = {
            callback($0.value, $0.error)
        }
        return block
    }
    
    private static func pipeError<T>(_ callback: NineAnimatorCallback<T>, perform: () throws -> NineAnimatorAsyncTask) -> NineAnimatorAsyncTask? {
        do {
            return try perform()
        } catch {
            callback(nil, error)
            return nil
        }
    }
}
