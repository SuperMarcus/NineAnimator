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

/// Special thanks to github@Awsomedude
extension NASourceNineAnimeOld {
    //    private static let magicValue = "0a9de5a4"
    //
    //    private func accumulate(_ content: String) -> Int {
    //        return content.unicodeScalars.enumerated().reduce(0) {
    //            accumulatedValue, currentItem in
    //            let (offset, element) = currentItem
    //            return accumulatedValue + offset + Int(element.value)
    //        }
    //    }
    //
    
    /// Sign the request parameters
    ///
    /// - Returns: The request signature (`_`) value
    private func sign(_ dict: [URLQueryItem]) -> Int {
        [0: 744, 1: 840, 2: 840, 3: 936][dict.count] ?? (685 + (dict.count * 48))
    }
    
    /// Retrieve the current timestamp `ts` value that should be
    /// included in the request
    private var currentNATimestamp: Int {
        Int(Date().timeIntervalSince1970 / 3600 - 12) * 3600
    }
    
    /// Sign the request url with parameters
    func signRequestURL(
        _ url: URL,
        withParameters parameters: [URLQueryItem]
    ) -> URL {
        // Construct signed request parameters
        var requestParameters = parameters
        requestParameters.append(.init(
            name: "_",
            value: String(sign(requestParameters))
            ))
        requestParameters.append(.init(
            name: "ts",
            value: String(currentNATimestamp)
            ))
        
        // Reconstruct the URL
        // swiftlint:disable redundant_nil_coalescing
        let reconstructedUrl = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        ) .unwrap {
            _components -> URL? in
            var components = _components
            components.queryItems = requestParameters
            return components.url
            } ?? nil // Well, unfortunetly the unwrap function returns URL??
        
        // Return the signed URL
        return reconstructedUrl ?? url
    }
    
    func renewSession(referer: String) -> NineAnimatorPromise<Void> {
        NineAnimatorPromise<Any>.queue(listOfPromises: [
            self.requestManager.request(
                "/clear.gif",
                headers: [
                    "Referer": referer,
                    "Accept": "image/png,image/svg+xml,image/*;q=0.8,video/*;q=0.8,*/*;q=0.5"
                ]
            ) .responseVoid,
            NineAnimatorPromise<Any> {
                callback in self.signedRequest(
                    ajax: "/user/ajax/menu-bar",
                    with: [ "Referer": referer ],
                    completion: callback
                )
            } .then { _ in () }
        ]) .then { _ in () }
    }
}
