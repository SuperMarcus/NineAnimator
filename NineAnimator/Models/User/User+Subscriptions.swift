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

// MARK: - Subscription store
extension NineAnimatorUser {
    /**
     Returns the list of anime currently set to be notified for updates
     */
    var subscribedAnimes: [AnimeLink] {
        get { decodeIfPresent([AnimeLink].self, from: _freezer.value(forKey: Keys.subscribedAnimeList)) ?? [] }
        set {
            guard let data = encodeIfPresent(data: newValue) else {
                return Log.error("Subscribed animes failed to encode")
            }
            _freezer.set(data, forKey: Keys.subscribedAnimeList)
        }
    }
    
    /**
     Return if the provided link is being watched
     */
    func isSubscribing(anime: AnimeLink) -> Bool {
        subscribedAnimes.contains { $0 == anime }
    }
    
    /**
     An alias of isSubscribing(anime: AnimeLink)
     */
    func isSubscribing(_ anime: Anime) -> Bool { isSubscribing(anime: anime.link) }
    
    /**
     Add the anime to the watch list
     */
    func subscribe(anime: Anime) {
        subscribe(uncached: anime.link)
        UserNotificationManager.default.update(anime, shouldFireSubscriptionEvent: true)
    }
    
    /**
     Add AnimeLink to watch list but don't cache all the episodes just yet
     */
    func subscribe(uncached link: AnimeLink) {
        var newWatchList = subscribedAnimes.filter { $0 != link }
        newWatchList.append(link)
        subscribedAnimes = newWatchList
        UserNotificationManager.default.lazyPersist(link, shouldFireSubscriptionEvent: true)
    }
    
    /**
     An alias of unwatch(anime: AnimeLink)
     */
    func unsubscribe(anime: Anime) { unsubscribe(anime: anime.link) }
    
    /**
     Remove the anime from the watch list
     */
    func unsubscribe(anime link: AnimeLink) {
        subscribedAnimes = subscribedAnimes.filter { $0 != link }
        UserNotificationManager.default.remove(link)
    }
    
    /**
     Remove all watched anime
     */
    func unsubscribeAll() {
        subscribedAnimes.forEach(UserNotificationManager.default.remove)
        subscribedAnimes = []
    }
}
