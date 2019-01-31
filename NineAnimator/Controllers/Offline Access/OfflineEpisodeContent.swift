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

import AVKit
import Foundation

/// Preserving video
class OfflineEpisodeContent: OfflineContent {
    private(set) var episodeLink: EpisodeLink
    
    // Assign anime object if has it
    var anime: Anime?
    
    override var identifier: String { return episodeLink.identifier }
    
    // Hold reference to the current task
    private var currentTask: NineAnimatorAsyncTask?
    
    required init?(_ manager: OfflineContentManager, from properties: [String: Any], initialState: OfflineState) {
        // Decode link from properties
        guard let linkData = properties["link"] as? Data else { return nil }
        guard let link = decode(episodeLink: linkData) else { return nil }
        episodeLink = link
        
        super.init(manager, from: properties, initialState: initialState)
    }
    
    init(_ episodeLink: EpisodeLink, parent: OfflineContentManager) {
        self.episodeLink = episodeLink
        super.init(parent, initialState: .ready)
        
        // Store link into the persisted proeprties
        persistedProperties["link"] = encode(episodeLink)!
    }
    
    override func preserve() {
        super.preserve()
        
        // Return if already preserved
        if case .preserved = state { return }
        
        if let anime = anime {
            currentTask = anime.episode(with: episodeLink) {
                [weak self] episode, error in
                guard let self = self else { return }
                
                guard let episode = episode else {
                    self.state = .error(error ?? NineAnimatorError.responseError("Unknown error"))
                    return
                }
                
                // Retrive content
                self.currentTask = episode.retrive {
                    [weak self] media, error in
                    guard let self = self else { return }
                    
                    guard let media = media else {
                        self.state = .error(error ?? NineAnimatorError.responseError("Unknown error"))
                        return
                    }
                    
                    // Preserve media if it exists
                    self.preserve(media: media)
                }
            }
        } else {
            currentTask = episodeLink.parent.retrive {
                [weak self] anime, error in
                guard let self = self else { return }
                
                guard let anime = anime else {
                    self.state = .error(error ?? NineAnimatorError.responseError("Unknown error"))
                    return
                }
                
                self.anime = anime
                self.preserve()
            }
        }
        
        // Update state at last
        state = .preservationInitialed
    }
    
    /// Preserve playback media
    func preserve(media: PlaybackMedia) {
        guard episodeLink == media.link else { return }
        
        // Return if already preserved
        if case .preserved = state { return }
        
        // Preserve using the AVAssetDownloadURLSession
        if media.isAggregated {
            guard let episodeAsset = media.avPlayerItem.asset as? AVURLAsset else {
                state = .error(NineAnimatorError.providerError("The asset is invalid"))
                return
            }
            let artworkData = artwork(for: episodeLink.parent)?.jpegData(compressionQuality: 0.8)
            task = assetDownloadingSession.makeAssetDownloadTask(
                asset: episodeAsset,
                assetTitle: "\(episodeLink.parent.title) - Episode \(episodeLink.name)",
                assetArtworkData: artworkData,
                options: nil
            )
        } else {
            guard let episodeAssetRequest = media.urlRequest else {
                state = .error(NineAnimatorError.providerError("This episode does not support offline access"))
                return
            }
            task = downloadingSession.downloadTask(with: episodeAssetRequest)
        }
        
        // Resumes the task
        task?.resume()
    }
    
    override func suggestName(for url: URL) -> String {
        return "\(episodeLink.parent.title) - Episode \(episodeLink.name)"
    }
    
    override func onCompletion(with url: URL) {
        super.onCompletion(with: url)
    }
    
    override func onCompletion(with error: Error) {
        super.onCompletion(with: error)
    }
}

private func decode(episodeLink data: Data) -> EpisodeLink? {
    return try? PropertyListDecoder().decode(EpisodeLink.self, from: data)
}

private func encode(_ link: EpisodeLink) -> Data? {
    return try? PropertyListEncoder().encode(link)
}
