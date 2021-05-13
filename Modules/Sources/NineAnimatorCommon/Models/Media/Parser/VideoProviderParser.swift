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
import AVKit
import Foundation

/// Representing a streaming resource parser that accepts an URL to
/// the streaming source's website and returns the resource URL.
public protocol VideoProviderParser {
    typealias Purpose = VideoProviderParserParsingPurpose
    
    /// Alternative names of this streaming source
    var aliases: [String] { get }
    
    /// Obtain the playback media for the episode target
    func parse(episode: Episode, with session: Session, forPurpose purpose: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask
    
    /// Check if the result from this parser is recommended for the given purpose
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool
}

// MARK: - Definitions & Helpers
public extension VideoProviderParser {
    var defaultUserAgent: String {
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36"
    }
    
    /// Check if the content type infers an aggregated asset
    static func isAggregatedAsset(mimeType: String) -> Bool {
        let loweredMimeType = mimeType.lowercased()
        return loweredMimeType == "application/x-mpegurl" || loweredMimeType == "vnd.apple.mpegurl"
    }
    
    /// Obtain the shared instance of this VideoProviderParser
    static var registeredInstance: Self? {
        VideoProviderRegistry.default.provider(Self.self)
    }
}

/// Annotate the purpose of parsing
public enum VideoProviderParserParsingPurpose: Int, CaseIterable, Equatable, Hashable {
    /// Mark the parsing as for local playback purpose
    case playback
    
    /// Mark the parsing as for external Google Cast playback purpose
    case googleCast
    
    /// Mark the parsing as for downloading purpose
    case download
}
