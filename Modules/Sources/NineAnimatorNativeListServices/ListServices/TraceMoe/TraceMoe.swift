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
import NineAnimatorCommon
import UIKit

public class TraceMoe {
    var apiURL: URL { URL(string: "https://api.trace.moe")! }

    let requestManager = NAEndpointRelativeRequestManager()
    
    public init() {}

    public func search(with image: UIImage) -> NineAnimatorPromise<[TraceMoeSearchResult]> {
        NineAnimatorPromise<Data>.firstly {
            guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
                throw NineAnimatorError.unknownError("Could not convert image to jpeg.")
            }
            return jpegData
        } .thenPromise {
            jpegData -> NineAnimatorPromise<TraceMoeSearchResponse> in
            let jsonDecoder = JSONDecoder()
            jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let request = self.requestManager.request { session in
                return self.requestManager.session.upload(
                    multipartFormData: { form in
                    form.append(jpegData, withName: "image", fileName: "image", mimeType: "image/jpeg")
                    },
                    to: self.apiURL.appendingPathComponent("/search").absoluteString + "?anilistInfo"
                )
            }
            
            return request
                .onReceivingResponse { try self.validateResponse($0) }
                .responseDecodable(type: TraceMoeSearchResponse.self, decoder: jsonDecoder)
        } .then {
            responseObject in
            let filteredResponses = responseObject.result.filter { $0.similarity >= 0.6 }
            guard !filteredResponses.isEmpty else { throw NineAnimatorError.searchError("No Results Found") }
            return filteredResponses
        }
    }
    
    public func search(with imageURL: URL) -> NineAnimatorPromise<[TraceMoeSearchResult]> {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return self.requestManager.request(
            url: self.apiURL.appendingPathComponent("/search"),
            method: .post,
            query: [
                "url": imageURL.absoluteString,
                "anilistInfo": ""
            ]
        )
        .onReceivingResponse { try self.validateResponse($0) }
        .responseDecodable(type: TraceMoeSearchResponse.self, decoder: jsonDecoder)
        .then {
            responseObject in
            let filteredResponses = responseObject.result.filter { $0.similarity >= 0.6 }
            guard !filteredResponses.isEmpty else { throw NineAnimatorError.searchError("No Results Found") }
            return filteredResponses
        }
    }

    private func validateResponse(_ response: NARequestManager.Response) throws {
        guard let HTTPresponse = response.response else { return }
        switch HTTPresponse.statusCode {
        case 400:
            throw NineAnimatorError.searchError("Image Was Not Provided")
        case 413:
            throw NineAnimatorError.searchError("Your image was above 10MB")
        case 429:
            throw NineAnimatorError.searchError("You are hitting the rate limiter. Calm down!")
        case 500..<600:
            if let data = response.data, let errorString = String(data: data, encoding: .utf8) {
                throw NineAnimatorError.searchError("Trace.moe experienced a backend error: \(errorString)")
            }
            throw NineAnimatorError.searchError("Trace.moe experienced a backend error")
        default: break
        }
    }
}

// MARK: - Data Types
public extension TraceMoe {
    struct TraceMoeSearchResponse: Codable {
        public let result: [TraceMoeSearchResult]
    }

    struct TraceMoeSearchResult: Codable {
        public let from, to: Double
        public let anilist: TraceMoeAnilistInfo
        public let filename: String
        public let video: URL
        public let image: URL
        public let episode: TraceMoeEpisode?
        public let similarity: Double
    }
    
    struct TraceMoeAnilistInfo: Codable {
        public let id, idMal: Int
        public let title: TraceMoeAnilistTitle
        public let synonyms: [String]
        public let isAdult: Bool
    }
    
    struct TraceMoeAnilistTitle: Codable {
        public let romaji: String?
        public let english: String?
        public let native: String?
        public let userPreferred: String?
    }

    /// Abstracts Trace.moe's custom episode type to a string value type
    struct TraceMoeEpisode: Codable {
        public let value: String

        public init(_ value: String) {
            self.value = value
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                value = str
            } else if let int = try? container.decode(Int.self) {
                value = String(int)
            } else if let double = try? container.decode(Double.self) {
                value = String(double)
            } else if let array = try? container.decode([Int].self) {
                value = array.description
            } else {
                throw DecodingError.typeMismatch(String.self, .init(codingPath: decoder.codingPath, debugDescription: "Could not convert trace.moe episode into String"))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
    }
}
