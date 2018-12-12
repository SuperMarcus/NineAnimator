//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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
import Alamofire

protocol SourceProtocol {
    var name: String { get }
    
    var retriverSession: Alamofire.SessionManager { get }
    
    func featured(_ handler: @escaping NineAnimatorCallback<FeaturedProtocol>) -> NineAnimatorAsyncTask?
    
    func anime(from link: AnimeLink, _ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask?
    
    func episode(from link: EpisodeLink, with anime: Anime, _ handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask?
    
    func search(keyword: String) -> SearchProtocol
}

/**
 Class BaseSource: all the network functions that the subclasses will ever need
 */
class BaseSource {
    let parent: NineAnimator
    
    var endpoint: String { return "" }
    
    var retriverSession: Alamofire.SessionManager { return parent.session }
    
    init(with parent: NineAnimator) {
        self.parent = parent
    }
    
    func request(browse url: URL, headers: [String: String], completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        return parent.session.request(url, headers: headers).responseString{
            response in
            switch response.result {
            case .failure(let error):
                debugPrint("Error: request to \(url) failed - \(error)")
                handler(nil, error)
            case .success(let value):
                handler(value, nil)
            }
        }
    }
    
    func request(ajax url: URL, headers: [String: String], completion handler: @escaping NineAnimatorCallback<NSDictionary>) -> NineAnimatorAsyncTask? {
        return parent.ajaxSession.request(url, headers: headers).responseJSON {
            response in
            switch response.result {
            case .failure(let error):
                debugPrint("Error: Request to \(url) failed - \(error)")
                handler(nil, error)
            case .success(let value as NSDictionary):
                handler(value, nil)
            default:
                debugPrint("Error: Unable to convert response value to NSDictionary")
                handler(nil, NineAnimatorError.responseError("Invalid Response"))
            }
        }
    }
    
    func request(ajaxString url: URL, headers: [String: String], completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        return parent.ajaxSession.request(url, headers: headers).responseString{
            response in
            switch response.result {
            case .failure(let error):
                debugPrint("Error: request to \(url) failed - \(error)")
                handler(nil, error)
            case .success(let value):
                handler(value, nil)
            }
        }
    }
    
    func request(browse path: String, completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        return request(browse: path, with: [:], completion: handler)
    }
    
    func request(browse path: String, with headers: [String: String], completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        guard let url = URL(string: "\(endpoint)\(path)") else {
            debugPrint("Error: Unable to parse URL with endpoint \"\(endpoint)\" at path \"\(path)\"")
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        return request(browse: url, headers: headers, completion: handler)
    }
    
    func request(ajax path: String, completion handler: @escaping NineAnimatorCallback<NSDictionary>) -> NineAnimatorAsyncTask? {
        return request(ajax: path, with: [:], completion: handler)
    }
    
    func request(ajax path: String, with headers: [String: String], completion handler: @escaping NineAnimatorCallback<NSDictionary>) -> NineAnimatorAsyncTask? {
        guard let url = URL(string: "\(endpoint)\(path)") else {
            debugPrint("Error: Unable to parse URL with endpoint \"\(endpoint)\" at path \"\(path)\"")
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        return request(ajax: url, headers: headers, completion: handler)
    }
    
    func request(ajaxString path: String, completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        return request(ajaxString: path, with: [:], completion: handler)
    }
    
    func request(ajaxString path: String, with headers: [String: String], completion handler: @escaping NineAnimatorCallback<String>) -> NineAnimatorAsyncTask? {
        guard let url = URL(string: "\(endpoint)\(path)") else {
            debugPrint("Error: Unable to parse URL with endpoint \"\(endpoint)\" at path \"\(path)\"")
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        return request(ajaxString: url, headers: headers, completion: handler)
    }
}
