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

/// A centralized registry for all streming source parsers
public class VideoProviderRegistry {
    /// The default streaming source parser regsitry
    public static let `default`: VideoProviderRegistry = {
        let defaultProvider = VideoProviderRegistry()
        
        // Default parsers
        defaultProvider.register(DummyParser(), forServer: "Dummy")
        defaultProvider.register(PassthroughParser(), forServer: "Passthrough")
        
        return defaultProvider
    }()
    
    private var providers = [(server: String, provider: VideoProviderParser)]()
    
    public func register(_ provider: VideoProviderParser, forServer server: String) {
        providers.append((server, provider))
    }
    
    public func provider(for server: String) -> VideoProviderParser? {
        (providers.first {
            // Compare server name then compare aliases
            $0.server.lowercased() == server.lowercased() || $0.provider.aliases.contains {
                $0.lowercased() == server.lowercased()
            }
        })?.provider
    }
    
    public func provider<Provider: VideoProviderParser>(_ type: Provider.Type) -> Provider? {
        providers.first { $0.provider is Provider }?.provider as? Provider
    }
}
