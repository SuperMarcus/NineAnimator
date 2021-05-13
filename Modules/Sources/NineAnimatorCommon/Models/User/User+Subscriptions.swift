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

// MARK: - Subscription store
public extension NineAnimatorUser {
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
            NotificationCenter.default.post(name: .subscriptionsDidUpdate, object: self)
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
        let link = anime.link
        var newWatchList = subscribedAnimes.filter { $0 != link }
        newWatchList.append(link)
        
        self.subscribedAnimes = newWatchList
        self._animeSubscriptionListeners.forEach {
            $0.listener?.userSubscription(didSubscribeLoadedAnime: anime)
        }
    }
    
    /**
     Add AnimeLink to watch list but don't cache all the episodes just yet
     */
    func subscribe(uncached link: AnimeLink) {
        var newWatchList = subscribedAnimes.filter { $0 != link }
        newWatchList.append(link)
        
        self.subscribedAnimes = newWatchList
        self._animeSubscriptionListeners.forEach {
            $0.listener?.userSubscription(didSubscribeLink: link)
        }
    }
    
    /**
     Move AnimeLink from one index to another index in the user's watch list
     */
    func moveSubscription(fromIndex sourceIndex: Int, toIndex destinationIndex: Int) {
        // Ensure index is in bounds of array
        guard (0...subscribedAnimes.count - 1).contains(sourceIndex) else {
            return Log.error("[User+Subscriptions] Tried to move subscription from index that is out of bounds.")
        }
        let originalSubscriptionAnimeLink = subscribedAnimes.remove(at: sourceIndex)
        subscribedAnimes.insert(originalSubscriptionAnimeLink, at: destinationIndex)
    }
    
    /**
     An alias of moveSubscription(fromIndex:toIndex)
     */
    func moveSubscription(withLink animeLink: AnimeLink, toIndex destinationIndex: Int) {
        guard let indexOfAnimeLink = subscribedAnimes.firstIndex(of: animeLink) else {
            return Log.error("[User+Subscription] Tried moving an animeLink that does not exist in the user's subscribed anime)")
        }
        moveSubscription(fromIndex: indexOfAnimeLink, toIndex: destinationIndex)
    }
    
    /**
     An alias of unwatch(anime: AnimeLink)
     */
    func unsubscribe(anime: Anime) { unsubscribe(anime: anime.link) }
    
    /**
     Remove the anime from the watch list
     */
    func unsubscribe(anime link: AnimeLink) {
        self.subscribedAnimes = subscribedAnimes.filter { $0 != link }
        self._animeSubscriptionListeners.forEach {
            $0.listener?.userSubscription(didUnsubscribeLink: link)
        }
    }
    
    /**
     Remove all watched anime
     */
    func unsubscribeAll() {
        let subscribedLinks = subscribedAnimes
        self.subscribedAnimes = []
        self._animeSubscriptionListeners.forEach {
            $0.listener?.userSubscription(didUnsubscribeAllAnime: subscribedLinks)
        }
    }
    
    func addSubscriptionListener(_ listener: UserSubscriptionListener) {
        self._animeSubscriptionListeners.append(.init(listener: listener))
    }
}

/// An object that listens for changes in user subscriptions
public protocol UserSubscriptionListener: AnyObject {
    func userSubscription(didSubscribeLink link: AnimeLink)
    func userSubscription(didSubscribeLoadedAnime anime: Anime)
    func userSubscription(didUnsubscribeLink link: AnimeLink)
    func userSubscription(didUnsubscribeAllAnime links: [AnimeLink])
}

extension NineAnimatorUser {
    internal struct AnyUserSubscriptionListener {
        internal weak var listener: UserSubscriptionListener?
    }
}
