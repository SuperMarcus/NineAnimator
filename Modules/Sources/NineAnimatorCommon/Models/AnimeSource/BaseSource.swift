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

/**
 Class BaseSource: all the network functions that the subclasses will ever need
 */
open class BaseSource {
    public let parent: NineAnimator
    
    open var endpoint: String { "" }
    
    open var endpointURL: URL { URL(string: endpoint)! }
    
    // Default to enabled
    open var isEnabled: Bool { true }
    
    @AtomicProperty private var _internalTaskReferences
        = [ObjectIdentifier: NineAnimatorAsyncTask]()
    
    /// The network request manager of the source
    public lazy var requestManager = NABaseSourceRequestManager(parent: self)
    
    /// The session used to create ajax requests
    public var retriverSession: Session { requestManager.session }
    
    /// The session used to create browsing requests
    public var browseSession: Session { requestManager.session }
    
    /// The user agent that should be used with requests
    open var sessionUserAgent: String { requestManager.currentIdentity }
    
    public init(with parent: NineAnimator) {
        self.parent = parent
    }
    
    /**
     Test if the url belongs to this source
     
     The default logic to test if the url belongs to this source is to see if
     the host name of this url ends with the source's endpoint.
     
     Subclasses should override this method if the anime watching url is
     different from the enpoint url.
     */
    open func canHandle(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return endpoint.hasSuffix(host)
    }
    
    /// Default `recommendServer(for:)` implementation
    ///
    /// The default recommendation behavior is to find the first streaming
    /// source whose name is registered in the default VideoProviderRegistry
    open func recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
        let availableServers = anime.servers
        return availableServers.first {
            VideoProviderRegistry.default.provider(for: $0.value) != nil
            || VideoProviderRegistry.default.provider(for: $0.key) != nil
        }?.key
    }
    
    /// Default `recommendServers(for, ofPurpose:)` implementation
    ///
    /// This implementation recommend servers by trying to obtain the provider for each server
    /// and check if the provider is being recommended for the specified purpose
    open func recommendServers(for anime: Anime, ofPurpose purpose: VideoProviderParser.Purpose) -> [Anime.ServerIdentifier] {
        let availableServers = anime.servers
        let registry = VideoProviderRegistry.default
        
        return availableServers.compactMap {
            // Try to obtain the parser and check if its recommended for the
            // specified purpose
            if let provider = registry.provider(for: $0.value) ?? registry.provider(for: $0.key),
                provider.isParserRecommended(forPurpose: purpose) {
                return $0.key
            } else { return nil }
        }
    }
}

// MARK: - Internal Task Management
public extension BaseSource {
    /// Keep a reference to an internal task
    func retainInternalTask(_ task: NineAnimatorAsyncTask) {
        __internalTaskReferences.mutate {
            $0[ObjectIdentifier(task)] = task
        }
    }
    
    /// Release a reference to an internal task
    func releaseInternalTask(_ task: NineAnimatorAsyncTask) {
        _ = __internalTaskReferences.mutate {
            $0.removeValue(forKey: ObjectIdentifier(task))
        }
    }
}
