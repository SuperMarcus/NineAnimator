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

import AVKit
import Foundation

/// Preserving video
class OfflineEpisodeContent: OfflineContent {
    private(set) var episodeLink: EpisodeLink
    
    /// The maximal number of times that NineAnimator is allowed to retry
    /// the download
    ///
    /// This variable defines how many times NineAnimator should reattempt
    /// downloading the fetched media before resetting it back to nil.
    var maximalAllowedRetryCount: Int {
        return 5
    }
    
    /// Assign anime object if has it
    var anime: Anime?
    
    /// The number of times that the content retried to preserve the content
    var retryCount = 0
    
    /// Retrive the playback media from the offline content
    var media: PlaybackMedia? {
        // Reuse the urlAsset as much as possible
        if isAggregatedAsset,
            let aggregateAssetDownloadTask = task as? AVAssetDownloadTask,
            aggregateAssetDownloadTask.urlAsset.isPlayable {
            let asset = aggregateAssetDownloadTask.urlAsset
            return OfflinePlaybackMedia(
                link: episodeLink,
                isAggregated: true,
                asset: asset
            )
        }
        
        guard let url = preservedContentURL else { return nil }
        
        // Check the validity of the resource
        guard (try? url.checkResourceIsReachable()) == true else { return nil }
        
        // Construct url asset
        let asset = AVURLAsset(
            url: url,
            options: [ AVURLAssetHTTPHeaderFieldsKey: sourceRequestHeaders ]
        )
        
        // Check if the asset is playable
        guard asset.isPlayable else { return nil }
        
        // Construct offline playback media
        return OfflinePlaybackMedia(
            link: episodeLink,
            isAggregated: isAggregatedAsset,
            asset: asset
        )
    }
    
    override var localizedDescription: String {
        return "Ep. \(episodeLink.name) - \(episodeLink.parent.title)"
    }
    
    override var identifier: String { return episodeLink.identifier }
    
    /// Hold reference to the current task
    private var currentTask: NineAnimatorAsyncTask?
    
    /// Cached retrieved playback media
    private var retrievedOnlineMedia: PlaybackMedia?
    
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
    
    // Disabling this checking for now. This is taking to much time to complete.
//    override func updateResourceAvailability() {
//        // If the state is preserved, make sure the media is retrievable
//        if case .preserved = state, media == nil {
//            task?.cancel()
//            task = nil
//            state = .ready
//        }
//        super.updateResourceAvailability()
//    }
    
    /// Collects the resource information and initiate downloads
    ///
    /// This method automatically tries to collect all the resources
    /// needed for downloading the episodes.
    override func preserve() {
        // Return if already preserved
        if case .preserved = state { return }
        
        // If the media has been retrieved
        if retryCount <= maximalAllowedRetryCount,
            let fetchedMedia = retrievedOnlineMedia {
            return self.preserve(media: fetchedMedia)
        }
        
        // Collect resource information and initiate downloads
        currentTask = collectResourceInformation().error {
            [weak self] in self?.onCompletion(with: $0)
        } .finally {
            [weak self] in self?.preserve(media: $0)
        }
        
        // Update state at last
        state = .preservationInitiated
    }
    
    /// Preserve playback media
    func preserve(media: PlaybackMedia) {
        guard episodeLink == media.link else { return }
        
        // Return if already preserved
        if case .preserved = state { return }
        
        if let basicMedia = media as? BasicPlaybackMedia {
            sourceRequestHeaders = basicMedia.headers
            sourceRequestUrl = basicMedia.url
        } else if let compositionalMedia = media as? CompositionalPlaybackMedia {
            sourceRequestHeaders = compositionalMedia.headers
            sourceRequestUrl = compositionalMedia.url
        } else {
            // Set state to error
            state = .error(NineAnimatorError.unknownError)
            return Log.error(
                "[OfflineEpisodeContent] Cannot preserve unsupported media: %@",
                media
            )
        }
        
        // Update hls flag
        isAggregatedAsset = media.isAggregated
        
        // Delete any previously downloaded content
        delete(shouldUpdateState: false)
        
        // Call the start method
        startResourceRequest()
    }
    
    override func cancel(shouldUpdateState flag: Bool = true) {
        // Cleanup current task
        currentTask?.cancel()
        currentTask = nil
        
        super.cancel(shouldUpdateState: flag)
    }
    
    override func suggestName(for url: URL) -> String {
        return "\(episodeLink.parent.title) - Episode \(episodeLink.name)"
    }
    
    override func onCompletion(with url: URL) {
        Log.info("[OfflineEpisodeContent] Downloaded to %@", url.absoluteString)
    }
    
    override func onCompletion(with error: Error) {
        // Retry downloads
        if retryCount < maximalAllowedRetryCount, let fetchedMedia = retrievedOnlineMedia {
            retryCount += 1
            Log.info("[OfflineEpisodeContent] Download finished with error: %@. Retrying...(%@/%@)", error, retryCount, maximalAllowedRetryCount)
            preserve(media: fetchedMedia)
        }
    }
}

// MARK: - Fetch and Download
private extension OfflineEpisodeContent {
    /// Collects information about the episode without initiating
    /// the downloads
    ///
    /// This method tries to gather all the necessary resources
    /// for downloading the episode. This includes Anime, Epiosde,
    /// as well as PlaybackMedia.
    func collectResourceInformation() -> NineAnimatorPromise<PlaybackMedia> {
        // Share a single queue to prevent some overhead
        let queue = DispatchQueue.global()
        return NineAnimatorPromise(queue: queue) {
            [weak self] (callback: @escaping NineAnimatorCallback<Anime>) in
            guard let self = self else { return nil }
            
            // If the anime has been retrieved
            if let anime = self.anime {
                callback(anime, nil)
                return nil
            }
            
            // If not, then retrieve the Anime object
            return self.episodeLink.parent.retrive {
                [weak self] anime, error in
                guard let self = self else { return }
                
                guard let anime = anime else {
                    return callback(nil, error)
                }
                
                self.anime = anime
                callback(anime, nil)
            }
        } .thenPromise {
            [weak self] anime in NineAnimatorPromise(queue: queue) {
                (callback: @escaping NineAnimatorCallback<Episode>) in
                guard let episodeLink = self?.episodeLink else { return nil }
                return anime.episode(with: episodeLink, onCompletion: callback)
            }
        } .thenPromise {
            [weak self] episode in NineAnimatorPromise(queue: queue) {
                (callback: @escaping NineAnimatorCallback<PlaybackMedia>) in
                guard self != nil else { return nil }
                return episode.retrive(onCompletion: callback)
            }
        } .then {
            [weak self] media in
            guard let self = self else { return nil }
            self.retrievedOnlineMedia = media
            return media
        }
    }
}

private func decode(episodeLink data: Data) -> EpisodeLink? {
    return try? PropertyListDecoder().decode(EpisodeLink.self, from: data)
}

private func encode(_ link: EpisodeLink) -> Data? {
    return try? PropertyListEncoder().encode(link)
}
