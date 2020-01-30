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

import AVFoundation
import Foundation

class CachableAVAssetLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    private var loadingRequestMap = [AVAssetResourceLoadingRequest: NineAnimatorAsyncTask]()
    
    private var bandwidth: String = "63701"
    private var codecs: String = "mp4a.40.34"
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if let requestingUrl = loadingRequest.request.url,
            let requestingScheme = requestingUrl.scheme {
            do {
                switch requestingScheme {
                case Scheme.eventPlaylist:
                    try generateMasterPlaylist(
                        url: requestingUrl,
                        forRequest: loadingRequest
                    )
                default:
                    throw NineAnimatorError.contentUnavailableError("Unknown scheme \(requestingScheme)")
                }
            } catch {
                Log.error("[CachableAVAssetLoaderDelegate] Unable to handle resource loading request: %@", error)
            }
        }
        
        return false
    }
}

// MARK: - Master Playlist Generation
private extension CachableAVAssetLoaderDelegate {
    func generateMasterPlaylist(url: URL, forRequest loadingRequest: AVAssetResourceLoadingRequest) throws {
        let masterPlaylist = """
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=\(bandwidth),CODECS="\(codecs)"
\(try swapScheme(forUrl: url, withNewScheme: Scheme.eventPlaylist).absoluteString)
"""
        let responseData = try masterPlaylist.data(using: .utf8).tryUnwrap()
        loadingRequest.dataRequest?.respond(with: responseData)
        loadingRequest.contentInformationRequest?.contentType = ""
    }
}

// MARK: - Definitions & Helpers
private extension CachableAVAssetLoaderDelegate {
    /// Definition of the private schemes used in the loader delegate
    enum Scheme {
        /// A link that contains a event playlist and needs a generated master playlist
        static var generateMasterPlaylist: String { "na-genmaster" }
        
        /// A link that points to a master playlist
        static var masterPlaylist: String { "na-master" }
        
        /// A link that points to an event playlist
        static var eventPlaylist: String { "na-event" }
        
        /// A link that points to an encryption key
        static var encryptionKey: String { "na-cryptkey" }
    }
    
    func swapScheme(forUrl originalUrl: URL, withNewScheme newScheme: String) throws -> URL {
        var components = try URLComponents(
            url: originalUrl,
            resolvingAgainstBaseURL: true
        ).tryUnwrap()
        components.scheme = newScheme
        return try components.url.tryUnwrap()
    }
}
