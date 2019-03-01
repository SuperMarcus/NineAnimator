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

import Foundation

/// Manages third party tracking for a particular AnimeLink
///
/// A `TrackingContext` is created with an Anime object,
/// passed on to the players for further updates, and released
/// when the user started watching another anime.
///
/// The `TrackingContext` keeps the anime listing references
/// of the provisioned `AnimeLink` no matter if the service
/// supports persisting progresses or listing services.
///
/// When an update is received, the `TrackingContext` passes
/// the event objects to the services that supports
/// progress persistence.
///
/// Currently events are received by playback notifications.
class TrackingContext {
    private var listingAnimeReferences = [String: ListingAnimeReference]()
    private var performingTaskPool = [NineAnimatorAsyncTask]()
    private let queue = DispatchQueue(label: "com.marcuszhou.NineAnimator.TrackingContext")
    
    private unowned var parent: NineAnimator
    private let link: AnimeLink
    private var current: EpisodeLink?
    
    init(_ parent: NineAnimator, link: AnimeLink) {
        self.parent = parent
        self.link = link
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPlaybackDidStart(_:)),
            name: .playbackDidStart,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPlaybackDidEnd(_:)),
            name: .playbackDidEnd,
            object: nil
        )
    }
    
    /// Retrieve the list of references that are loaded
    var availableReferences: [ListingAnimeReference] {
        return listingAnimeReferences.map { $0.1 }
    }
    
    /// Prepare this tracking context for updates
    ///
    /// TrackingContext must be prepared before being used
    func prepareContext() {
        Log.info("[TrackingContext] Preparing tracking context for \"%@\"", link.title)
        fetchReferences()
    }
    
    /// Set the anime to `watching` if it was in `toWatch` state
    ///
    /// See `beginWatching(episode: EpisodeLink)`
    func beginWatching(media: PlaybackMedia) {
        beginWatching(episode: media.link)
    }
    
    /// Set the anime to `watching` if it was in `toWatch` state
    ///
    /// Messages are only relayed to services that support
    /// persisting anime state
    func beginWatching(episode: EpisodeLink) {
        // Intentionally using a strong reference
        queue.async {
            guard episode.parent == self.link else {
                Log.error("[TrackingContext] Attempting to send a beginWatching message to a TrackingContext that does not belong to the media.")
                return
            }
            
            // Update the value to watching
            for (key, var reference) in self.listingAnimeReferences where reference.parentService.isCapableOfPersistingAnimeState {
                if reference.state == nil || reference.state == .toWatch {
                    reference.parentService.update(reference, newState: .watching)
                    reference.state = .watching
                    self.listingAnimeReferences[key] = reference
                    Log.info("[TrackingContext] Updating anime state to \"watching\" on \"%@\" for \"%@\"", reference.parentService.name, self.link.title)
                }
            }
            
            // At last, set the current episode link to episode
            self.current = episode
        }
    }
    
    func endWatching() {
        guard let episodeLink = current else {
            Log.error("[TrackingContext] Attempting to send a endWatching message to a TrackingContext that did not start")
            return
        }
        endWatching(episode: episodeLink)
    }
    
    /// Update progress of the anime
    ///
    /// See `endWatching(episode: EpisodeLink)`
    func endWatching(media: PlaybackMedia) {
        endWatching(episode: media.link)
    }
    
    /// Update progress of the anime
    ///
    /// Messages are only relayed to services that support
    /// persisting anime state
    func endWatching(episode: EpisodeLink) {
        queue.async {
            guard episode.parent == self.link else {
                Log.error("[TrackingContext] Attempting to send a endWatching message to a TrackingContext that does not belong to the media.")
                return
            }
            
            // Update states
            for (_, reference) in self.listingAnimeReferences where reference.parentService.isCapableOfPersistingAnimeState {
                reference.parentService.update(reference, didComplete: episode)
            }
        }
    }
    
    /// Fetch anime references if they do not exists
    private func fetchReferences() {
        queue.async {
            let link = self.link
            // Create reference fetching tasks
            for service in self.parent.trackingServices {
                let task = service.reference(from: link).error {
                    error in
                    Log.error("[TrackingContext] Cannot fetch tracking service reference for anime \"%@\": %@", link.title, error)
                } .finally {
                    [weak self, unowned service] reference in
                    self?.queue.async {
                        self?.listingAnimeReferences[service.name] = reference
                        Log.info("[TrackingContext] Matched to service \"%@\" (reference name: \"%@\" identifier \"%@\") with state \"%@\"", service.name, reference.name, reference.uniqueIdentifier, reference.state as Any)
                    }
                }
                self.performingTaskPool.append(task)
            }
        }
    }
    
    @objc private func onPlaybackDidStart(_ notification: Notification) {
        if let media = notification.userInfo?["media"] as? PlaybackMedia,
            media.link.parent == link {
            beginWatching(media: media)
        }
    }
    
    @objc private func onPlaybackDidEnd(_ notification: Notification) {
        if let media = notification.userInfo?["media"] as? PlaybackMedia,
            media.link.parent == link,
            media.progress > 0.7 { // Progress > 0.7 as finished watching this episode
            endWatching(media: media)
        }
    }
    
    private func collectGarbage() {
        // Remove any references to promises that have been resolved
        performingTaskPool.removeAll {
            ($0 as? NineAnimatorPromiseProtocol)?.isResolved ?? false
        }
    }
    
    deinit {
        if !availableReferences.isEmpty {
            Log.info("[TrackingContext] Releasing TrackingContext for anime \"%@\"", link.title)
        }
        NotificationCenter.default.removeObserver(self) // As unnecessary as this might be
    }
}
