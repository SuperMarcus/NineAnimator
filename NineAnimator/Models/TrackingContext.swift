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

/// Manages third party tracking and progress persistance for
/// a particular AnimeLink.
///
/// A `TrackingContext` is shared across the app for the same
/// AnimeLink, and destroyed upon reference counting release.
/// The NineAnimator object keeps a weak reference to each
/// TrackingContext to make sure maximal reusability. Thus,
/// TrackingContext should not be instantiated from contexts
/// other than the NineAnimator object.
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
    private var performingTaskPool = [NineAnimatorAsyncTask]()
    private let queue = DispatchQueue(label: "com.marcuszhou.NineAnimator.TrackingContext")
    
    private unowned var parent: NineAnimator
    private let link: AnimeLink
    private let stateConfigurationUrl: URL
    
    // Persisted states
    private var creationDate: Date
    private var relatedLinks: Set<AnimeLink>
    private var listingAnimeReferences = [String: ListingAnimeReference]()
    private var progressRecords = [PlaybackProgressRecord]()
    
    private var current: EpisodeLink?
    
    init(_ parent: NineAnimator, link: AnimeLink) {
        self.parent = parent
        self.link = link
        self.stateConfigurationUrl = try! TrackingContext.stateConfigurationUrl(for: link)
        self.relatedLinks = []
        self.creationDate = Date()
        
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
        
        restore()
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
                reference.parentService.update(
                    reference,
                    didComplete: episode,
                    episodeNumber: self.suggestingEpisodeNumber(for: episode)
                )
            }
            
            // Save states
            self.save()
        }
    }
    
    /// Fetch anime references if they do not exists
    private func fetchReferences() {
        queue.async {
            [queue] in
            let link = self.link
            // Create reference fetching tasks
            for service in self.parent.trackingServices {
                let task = service.reference(from: link)
                .dispatch(on: queue)
                .error {
                    error in
                    Log.error("[TrackingContext] Cannot fetch tracking service reference for anime \"%@\": %@", link.title, error)
                    self.collectGarbage()
                } .finally {
                    [unowned service] reference in
                    Log.info(
                        "[TrackingContext] Matched to service \"%@\" (reference name: \"%@\" identifier \"%@\") with state \"%@\"",
                        service.name,
                        reference.name,
                        reference.uniqueIdentifier,
                        reference.state as Any
                    )
                    self.listingAnimeReferences[service.name] = reference
                    self.discoverRelatedLinks(with: reference)
                    self.collectGarbage()
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
    
    class func stateConfigurationUrl(for link: AnimeLink) throws -> URL {
        let fileManager = FileManager.default
        let applicationSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .allDomainsMask,
            appropriateFor: nil,
            create: true
        )
        let trackingStateDirectory =  applicationSupportDirectory.appendingPathComponent("TrackingState", isDirectory: true)
        // Create the directory if it does not exists
        try fileManager.createDirectory(
            at: trackingStateDirectory,
            withIntermediateDirectories: true,
            attributes: [:]
        )
        return trackingStateDirectory
            .appendingPathComponent(link.link.uniqueHashingIdentifier, isDirectory: false)
            .appendingPathExtension("plist")
    }
    
    deinit {
        save()
        NotificationCenter.default.removeObserver(self) // As unnecessary as this might be
    }
}

// MARK: - Context relationships
extension TrackingContext {
    /// Find other tracking contexts with the same reference and share
    /// resources with them
    private func discoverRelatedLinks(with reference: ListingAnimeReference) {
        let recentAnime = self.parent.user.recentAnimes
        for comparingAnime in recentAnime where comparingAnime != self.link {
            let comparingTrackingContext = self.parent.trackingContext(for: comparingAnime)
            if comparingTrackingContext.listingAnimeReferences.contains(where: {
                _, value in value == reference
            }) {
                self.relatedLinks.insert(comparingAnime)
                _ = comparingTrackingContext.queue.sync {
                    comparingTrackingContext.relatedLinks.insert(self.link)
                }
            }
        }
        self.save()
    }
}

// MARK: - Playback progress persistence
extension TrackingContext {
    struct PlaybackProgressRecord: Codable {
        var episodeNumber: Int
        var progress: Double
        var enqueueDate: Date
    }
    
    /// Enqueue a new record for an episode with playback progress
    func updateRecord(_ progress: Double, forEpisodeNumber episode: Int) {
        queue.async {
            self.progressRecords.removeAll { $0.episodeNumber == episode }
            self.progressRecords.append(
                PlaybackProgressRecord(
                    episodeNumber: episode,
                    progress: progress,
                    enqueueDate: Date()
                )
            )
            self.save()
        }
    }
    
    /// Retrieve the latest playback record for the specific episode
    func retrieveLatestRecord(forEpisodeNumber episode: Int) -> PlaybackProgressRecord? {
        // Search the record in all related contexts
        var searchingContexts = relatedLinks.map { parent.trackingContext(for: $0) }
        searchingContexts.append(self)
        
        // Find the record for the episode number
        let availableEpisodeRecords = searchingContexts.compactMap {
            $0.progressRecords.first { $0.episodeNumber == episode }
        }
        
        // Return the latest record
        return availableEpisodeRecords.max { $0.enqueueDate < $1.enqueueDate }
    }
    
    /// Retrieve the playback progress for an episode
    func playbackProgress(for episodeLink: EpisodeLink) -> Double {
        // Using the conventional progress storage
        var fallbackProgress: Double { return Double(parent.user.playbackProgress(for: episodeLink)) }
        
        // Make sure that this tracking context owns the link
        guard episodeLink.parent == link else {
            Log.error("[TrackingContext] Attempting to retrieve progress records from a tracking context that the episode doesn't belongs to.")
            return fallbackProgress
        }
        
        // Retrieve the record
        var record: PlaybackProgressRecord?
        if let episodeNumber = suggestingEpisodeNumber(for: episodeLink) {
            record = retrieveLatestRecord(forEpisodeNumber: episodeNumber)
        }
        
        return record?.progress ?? fallbackProgress
    }
    
    /// Update the playback progress
    ///
    /// This also persists the progress to NineAnimatorUser
    func update(progress: Double, forEpisodeLink episodeLink: EpisodeLink) {
        parent.user.update(progress: Float(progress), for: episodeLink)
        
        // Only record this progress if the episode number can be inferred
        if let episodeNumber = suggestingEpisodeNumber(for: episodeLink) {
            updateRecord(progress, forEpisodeNumber: episodeNumber)
        }
    }
    
    /// Infer the episode number based on the name of the episode
    func suggestingEpisodeNumber(for episodeLink: EpisodeLink) -> Int? {
        // Conventionally in NineAnimator, the episode number always prefixes
        // the episode name with the rest of the name seperated by a space and
        // a dash (e.g. 01 - Episode Name)
        let episodeName = episodeLink.name
        
        // Get the prefix section
        guard let episodeNamePrefixSection = episodeName.split(separator: " ").first else {
            return nil
        }
        
        // If there is a clear episode number
        if let episodeNumber = Int(episodeNamePrefixSection) {
            return episodeNumber
        } else if let firstCharacterScalar = episodeNamePrefixSection.first?.unicodeScalars.first,
            !CharacterSet.decimalDigits.contains(firstCharacterScalar) {
            // This is to exclude something like "10-Preview"
            return 1
        }
        
        // Return nil otherwise
        return nil
    }
}

// MARK: - Persistance
extension TrackingContext {
    private enum Keys {
        static let `protocol` = "com.marcuszhou.nineanimator.TrackingContext.protocol"
        static let creationDate = "com.marcuszhou.nineanimator.TrackingContext.creation"
        static let link = "com.marcuszhou.nineanimator.TrackingContext.link"
        static let relatedLinks = "com.marcuszhou.nineanimator.TrackingContext.related"
        static let cachedReferences = "com.marcuszhou.nineanimator.TrackingContext.references"
        static let progressRecords = "com.marcuszhou.nineanimator.TrackingContext.progresses"
    }
    
    private func save() {
        do {
            var persistingInformation = [String: Any]()
            persistingInformation[Keys.protocol] = 1
            persistingInformation[Keys.creationDate] = creationDate
            persistingInformation[Keys.link] = try encode(data: link)
            persistingInformation[Keys.relatedLinks] = try encode(data: relatedLinks)
            persistingInformation[Keys.cachedReferences] = try encode(data: listingAnimeReferences)
            persistingInformation[Keys.progressRecords] = try encode(data: progressRecords)
            
            // Write to configuration url
            try PropertyListSerialization
                .data(fromPropertyList: persistingInformation, format: .binary, options: 0)
                .write(to: stateConfigurationUrl)
        } catch {
            Log.error("Unable to persist tracking context state data: %@", error)
        }
    }
    
    private func restore() {
        // Only restore if file exists
        guard FileManager.default.fileExists(atPath: stateConfigurationUrl.path) else {
            return
        }
        
        do {
            // Decode from configuration file
            let persistedInformationData = try Data(contentsOf: stateConfigurationUrl)
            guard let persistedInformation = try PropertyListSerialization.propertyList(
                from: persistedInformationData,
                options: [],
                format: nil
            ) as? [String: Any] else { throw NineAnimatorError.decodeError }
            
            // Check protocol version
            guard (persistedInformation[Keys.protocol] as? Int) == 1 else {
                Log.error("Cannot restore persisted tracking context: Unsupported protocol %@", String(describing: persistedInformation[Keys.protocol]))
                throw NineAnimatorError.decodeError
            }
            
            // Restore persisted links
            self.relatedLinks = try decode(Set<AnimeLink>.self, from: persistedInformation[Keys.relatedLinks])
            self.listingAnimeReferences = try decode([String: ListingAnimeReference].self, from: persistedInformation[Keys.cachedReferences])
            self.progressRecords = try decode([PlaybackProgressRecord].self, from: persistedInformation[Keys.progressRecords])
            self.creationDate = try some(
                persistedInformation[Keys.creationDate] as? Date,
                or: .decodeError
            )
        } catch {
            Log.error("Unable to decode persisted tracking context state data: %@", error)
        }
    }
}
