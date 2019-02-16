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

import Foundation

enum NineAnimatorError: Error, CustomStringConvertible {
    case urlError
    case responseError(String)
    case providerError(String)
    case searchError(String)
    case authenticationRequiredError(String, URL?)
    case decodeError
    case unknownError
    case lastItemInQueueError
    
    var description: String {
        switch self {
        case .decodeError: return  "Cannot decode an encoded media. This app might be outdated."
        case .urlError: return "There is something wrong with the URL"
        case .responseError(let errorString): return "Response Error: \(errorString)"
        case .providerError(let errorString): return "Provider Error: \(errorString)"
        case .searchError(let errorString): return "Search Error: \(errorString)"
        case .lastItemInQueueError: return "The selected item is the last item in the queue."
        case let .authenticationRequiredError(message, url):
            let urlDescription = url == nil ? "" : " (\(url!))"
            return "Authentication required: \(message)\(urlDescription)"
        case .unknownError: return "Unknwon Error"
        }
    }
}
