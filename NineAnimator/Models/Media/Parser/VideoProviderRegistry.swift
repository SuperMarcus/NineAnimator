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
class VideoProviderRegistry {
    /// The default streaming source parser regsitry
    static let `default`: VideoProviderRegistry = {
        let defaultProvider = VideoProviderRegistry()
        
        // A list of public parsers
        defaultProvider.register(MyCloudParser(), forServer: "MyCloud")
        defaultProvider.register(RapidVideoParser(), forServer: "RapidVideo")
        defaultProvider.register(StreamangoParser(), forServer: "Streamango")
        defaultProvider.register(Mp4UploadParser(), forServer: "Mp4Upload")
        defaultProvider.register(TiwiKiwiParser(), forServer: "Tiwi.Kiwi")
        defaultProvider.register(DummyParser(), forServer: "Dummy")
        defaultProvider.register(PassthroughParser(), forServer: "Passthrough")
        defaultProvider.register(PrettyFastParser(), forServer: "F5 - HQ")
        defaultProvider.register(OpenLoadParser(), forServer: "OpenLoad")
        defaultProvider.register(KiwikParser(), forServer: "Kiwik")
        defaultProvider.register(VidStreamingParser(), forServer: "VidStreaming")
        defaultProvider.register(XStreamParser(), forServer: "XStream")
        defaultProvider.register(NovaParser(), forServer: "Nova")
        defaultProvider.register(VeryStream(), forServer: "VeryStream")
        defaultProvider.register(HydraXParser(), forServer: "HydraX")
        defaultProvider.register(ProxyDataParser(), forServer: "ProxyData")
        defaultProvider.register(GoUnlimitedParser(), forServer: "GoUnlimited")
        defaultProvider.register(MixdropParser(), forServer: "Mixdrop")
        defaultProvider.register(CloudNineParser(), forServer: "Cloud9")
        defaultProvider.register(StreamTapeParser(), forServer: "Streamtape")
        defaultProvider.register(EasyLoadParser(), forServer: "Easyload")
        defaultProvider.register(ClipWatchingParser(), forServer: "ClipWatching")
        defaultProvider.register(UqloadParser(), forServer: "Uqload")
        defaultProvider.register(SendvidParser(), forServer: "Sendvid")
        defaultProvider.register(VideobinParser(), forServer: "Videobin")
        defaultProvider.register(FacebookParser(), forServer: "fserver")
        defaultProvider.register(YourUploadParser(), forServer: "yuserver")
        defaultProvider.register(OpenStreamParser(), forServer: "oserver")
        defaultProvider.register(VidStreamParser(), forServer: "Vidstream")
        defaultProvider.register(StreamSBParser(), forServer: "Streamsb")
        
        // Private parsers are registered from their own source instances
        return defaultProvider
    }()
    
    private var providers = [(server: String, provider: VideoProviderParser)]()
    
    func register(_ provider: VideoProviderParser, forServer server: String) {
        providers.append((server, provider))
    }
    
    func provider(for server: String) -> VideoProviderParser? {
        (providers.first {
            // Compare server name then compare aliases
            $0.server.lowercased() == server.lowercased() || $0.provider.aliases.contains {
                $0.lowercased() == server.lowercased()
            }
        })?.provider
    }
    
    func provider<Provider: VideoProviderParser>(_ type: Provider.Type) -> Provider? {
        providers.first { $0.provider is Provider }?.provider as? Provider
    }
}
