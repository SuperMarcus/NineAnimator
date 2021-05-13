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

public extension NineAnimatorCloud {
    struct APIResponse<DataType: Decodable>: Decodable {
        public var data: DataType?
        public var status: Int
        public var message: String
    }
    
    func requestServiceDescriptor() -> NineAnimatorPromise<ServiceDescriptor> {
        requestManager.request(resourcePath: "api/app/service_descriptor", responseType: ServiceDescriptor.self)
    }
    
    func requestSourceDescriptor<SourceDescriptorType: Decodable>(
        source: Source,
        descriptorType: SourceDescriptorType.Type
    ) -> NineAnimatorPromise<SourceDescriptorType> {
        requestManager.request(resourcePath: "api/app/source_descriptor/\(source.name)", responseType: descriptorType)
    }
}

/// A private network request manager used only by the NineAnimatorCloud service
public class NACloudRequestManager: NAEndpointRelativeRequestManager {
    unowned var parent: NineAnimatorCloud
    
    internal init(parent: NineAnimatorCloud) {
        self.parent = parent
        super.init(endpoint: NineAnimatorCloud.baseUrl)
    }
    
    public func request<ResponseType: Decodable>(resourcePath: String, responseType: ResponseType.Type) -> NineAnimatorPromise<ResponseType> {
        let customDecoder = JSONDecoder()
        customDecoder.dateDecodingStrategy = .iso8601
        customDecoder.keyDecodingStrategy = .convertFromSnakeCase
        customDecoder.dataDecodingStrategy = .base64
        
        return self.request(resourcePath)
            .responseDecodable(type: NineAnimatorCloud.APIResponse<ResponseType>.self, decoder: customDecoder)
            .then {
                responseObject in
                if (200..<300).contains(responseObject.status), let data = responseObject.data {
                    return data
                } else {
                    throw NineAnimatorError.NineAnimatorCloudError(statusCode: responseObject.status, message: responseObject.message)
                }
            }
    }
}
