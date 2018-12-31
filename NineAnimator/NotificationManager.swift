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

import Kingfisher
import UIKit
import UserNotifications

/**
 A structure used to persist episode information.
 */
struct WatchedAnime: Codable {
    let link: AnimeLink
    let episodeNames: [String]
    let lastCheck: Date
}

/**
 A standalone class used to manage fetch requests and updates
 */
class UserNotificationManager {
    // Exposed properties
    static let `default` = UserNotificationManager()
    
    let suggestedFetchInterval: TimeInterval = 7200
    
    // Private properties
    
    private var taskPool: [NineAnimatorAsyncTask?]? // Hold references to async tasks
    
    private let animeCachingDirectory: URL
    
    init() {
        let fileManager = FileManager.default
        
        self.animeCachingDirectory = try! fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}

// MARK: - File path helpers
extension UserNotificationManager {
    private func url(for anime: AnimeLink) -> URL {
        return self.animeCachingDirectory.appendingPathComponent(.animePersistFilenameComponent(anime))
    }
    
    private func posterUrl(for anime: AnimeLink) -> URL {
        return self.animeCachingDirectory.appendingPathComponent(.cachedPosterFilenameComponent(anime))
    }
}

// MARK: - Watcher Persistent
extension UserNotificationManager {
    /**
     Retrive the watcher for the anime from the file system
     */
    func retrive(for anime: AnimeLink) -> WatchedAnime? {
        do {
            let persistUrl = self.url(for: anime)
            if try persistUrl.checkResourceIsReachable() {
                let serializedWatcher = try Data(contentsOf: persistUrl)
                let decoer = PropertyListDecoder()
                return try decoer.decode(WatchedAnime.self, from: serializedWatcher)
            }
        } catch { debugPrint("Error: Unable to retrive watcher for anime - \(error)") }
        return nil
    }
    
    /**
     Persist the watcher for the anime to the file system
     */
    func persist(_ watcher: WatchedAnime) {
        do {
            let persistUrl = self.url(for: watcher.link)
            let encoder = PropertyListEncoder()
            let serializedWatcher = try encoder.encode(watcher)
            try serializedWatcher.write(to: persistUrl)
        } catch { debugPrint("Error: Unable to persist watcher - \(error)") }
    }
    
    /**
     Update cached anime episodes
     */
    func update(_ anime: Anime) {
        let newWatcher = WatchedAnime(
            link: anime.link,
            episodeNames: anime.episodes.uniqueEpisodeNames,
            lastCheck: Date()
        )
        persist(newWatcher)
    }
    
    /**
     Clear cached anime episodes
     */
    func remove(_ anime: AnimeLink) {
        do {
            let fileManager = FileManager.default
            try fileManager.removeItem(at: url(for: anime))
            try fileManager.removeItem(at: posterUrl(for: anime))
        } catch { debugPrint("Error: Unable to remove persisted watcher") }
    }
    
    /**
     Clear all cached anime
     */
    func removeAll() {
        do {
            let fileManager = FileManager.default
            let enumeratedItems = try fileManager.contentsOfDirectory(
                at: animeCachingDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsSubdirectoryDescendants]
            )
            try enumeratedItems.forEach(fileManager.removeItem)
        } catch { debugPrint("Error: Unable to remove persisted watcher") }
    }
    
    /**
     Remove posted notifications about this anime
     */
    func clearNotifications(for anime: AnimeLink) {
        let notificationCenter = UNUserNotificationCenter.current()
        let viewedAnimeNotificationIdentifiers: [String] = [.episodeUpdateNotificationIdentifier(anime)]
        notificationCenter.removeDeliveredNotifications(withIdentifiers: viewedAnimeNotificationIdentifiers)
    }
}

// MARK: - Perform episodes fetching
extension UserNotificationManager {
    fileprivate typealias FetchResult = (anime: AnimeLink, newEpisodeTitles: [String], availableServerNames: [String])
    
    func performFetch(with completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        //Do not perform fetch if the last one is incomeplete
        guard taskPool == nil else { return completionHandler(.failed) }
        
        let watchedAnimeLinks = NineAnimator.default.user.watchedAnimes
        var resultsPool = [FetchResult?]()
        
        guard !watchedAnimeLinks.isEmpty else {
            return completionHandler(.noData)
        }
        
        func onFinalTask() {
            let succeededResultsCount = resultsPool
                .compactMap { $0 }
                .count
            let newResultsCount = resultsPool
                .filter { ($0?.newEpisodeTitles.count ?? 0) > 0 }
                .count
            let finalFetchResult: UIBackgroundFetchResult =
                succeededResultsCount == watchedAnimeLinks.count ?
                ( newResultsCount > 0 ? .newData : .noData )
                : .failed
            completionHandler(finalFetchResult)
            debugPrint("Info: Background fetch finished with result: \(finalFetchResult)")
            taskPool = nil
        }
        
        debugPrint("Info: Beginning background fetch with \(watchedAnimeLinks.count) watched anime.")
        
        taskPool = watchedAnimeLinks.map { animeLink in
            animeLink.retrive { anime, _ in
                defer { if resultsPool.count == watchedAnimeLinks.count { onFinalTask() } }
                
                guard let anime = anime else { return resultsPool.append(nil) }
                
                var result = FetchResult(animeLink, [], [])
                
                if let currentWatcher = self.retrive(for: animeLink) {
                    result.newEpisodeTitles = anime.episodes.uniqueEpisodeNames.filter {
                        !currentWatcher.episodeNames.contains($0)
                    }
                    result.availableServerNames = result
                        .newEpisodeTitles
                        .flatMap(anime.episodes.links)
                        .reduce(into: [Anime.ServerIdentifier]()) {
                            if !$0.contains($1.server) {
                                $0.append($1.server)
                            }
                        }
                        .compactMap { anime.servers[$0] }
                    
                    //Post notification to user
                    self.notify(result: result)
                }
                
                //If unable to retrive the persisted episodes (maybe deleted by the system)
                //Just store the latest version without posting any notifications.
                self.update(anime)
                
                resultsPool.append(result)
            }
        }
    }
    
    /**
     Post notification to user
     */
    private func notify(result: FetchResult) {
        guard !result.newEpisodeTitles.isEmpty else { return }
        
        let notificationCenter = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        
        content.title = "\(result.anime.title)"
    
        let streamingSites = result.availableServerNames.joined(separator: ", ")
        let sourceName = result.anime.source.name
        
        if result.newEpisodeTitles.count == 1 {
            content.body = "Episode \(result.newEpisodeTitles.first!) is now available on \(sourceName)."
        } else {
            content.body = "\(result.newEpisodeTitles.count) more episodes are now available on \(sourceName)."
        }
        
        //Sometimes showing what stream the anime is on can be helpful
        if NineAnimator.default.user.notificationShowStreams {
            content.body += " Stream now from \(streamingSites)."
        }
        
        do {
            let posterUrl = self.posterUrl(for: result.anime)
            
            let cache = Kingfisher.ImageCache.default
            let cacheKey = result.anime.image.absoluteString
            let cachedPosterPath = cache.cachePath(forKey: cacheKey)
            
            //Only show poster if the poster is cached, or an error is expected to be thrown
            let poster = UIImage(contentsOfFile: cachedPosterPath)
            try poster?.jpegData(compressionQuality: 0.8)?.write(to: posterUrl)
            
            let posterAttachment = try UNNotificationAttachment(
                identifier: "",
                url: posterUrl,
                options: nil
            )
            content.attachments.append(posterAttachment)
        } catch { debugPrint("Error: Unable to attach poster to notification - \(error)") }
        
        let request = UNNotificationRequest(
            identifier: .episodeUpdateNotificationIdentifier(result.anime),
            content: content,
            trigger: nil
        )
        
        //Alas, post notification to the user
        notificationCenter.add(request, withCompletionHandler: nil)
    }
}

// MARK: - Notification identifiers/File Name paths
extension String {
    static func episodeUpdateNotificationIdentifier(_ anime: AnimeLink) -> String {
        return "com.marcuszhou.NineAnimator.notification.episodeUpdates.\(anime.link.hashValue)"
    }
    
    static func animePersistFilenameComponent(_ anime: AnimeLink) -> String {
        //As short as possible
        let linkHashRepresentation = String(anime.link.hashValue, radix: 36, uppercase: true)
        return "com.marcuszhou.NineAnimator.anime.\(linkHashRepresentation).plist"
    }
    
    static func cachedPosterFilenameComponent(_ anime: AnimeLink) -> String {
        let linkHashRepresentation = String(anime.link.hashValue, radix: 36, uppercase: true)
        return "com.marcuszhou.NineAnimator.poster.\(linkHashRepresentation).jpg"
    }
}
