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

import UIKit

extension LibrarySceneController {
    class SubscriptionAvailableTip: Tip {
        private var subscribedAnime: [AnimeLink]
        
        fileprivate init(_ updatedAnime: [AnimeLink]) {
            self.subscribedAnime = updatedAnime
            super.init()
        }
        
        fileprivate func updateCollection(_ updated: [AnimeLink]) {
            self.subscribedAnime = updated
        }
        
        override func onSelection(_ collectionView: UICollectionView, at indexPath: IndexPath, selectedCell: UICollectionViewCell, parent: LibrarySceneController) {
            // Open the anime if there's only one that's updated
            if subscribedAnime.count == 1,
                let anime = subscribedAnime.first {
                RootViewController.shared?.open(
                    immedietly: .anime(anime),
                    in: parent
                )
            } else if let category = parent.category(withIdentifier: "library.category.subscribed") {
                // Else present the subscription category
                parent.present(category: category)
            }
        }
        
        override func setupCell(_ collectionView: UICollectionView, at indexPath: IndexPath, parent: LibrarySceneController) -> UICollectionViewCell {
            let cell =  collectionView.dequeueReusableCell(
                withReuseIdentifier: "library.tips.subscribed",
                for: indexPath
            ) as! LibraryTipSubscriptionAvailableCell
            cell.setPresenting(subscribedAnime)
            return cell
        }
    }
    
    /// Initialize & reload the list of tips
    func reloadTips() {
        // Subscription Tip
        if _subscribedAnimeNotificationRetrivalTask == nil {
            _subscribedAnimeNotificationRetrivalTask = UserNotificationManager
                .default
                .animeWithNotifications()
                .dispatch(on: .main)
                .error {
                    [weak self] error in
                    Log.error("[LibrarySceneController] Unable to retrieve updated anime list: %@", error)
                    self?._subscribedAnimeNotificationRetrivalTask = nil
                } .finally {
                    [weak self] results in
                    guard let self = self else { return }
                    if results.isEmpty {
                        // If no more notification remains, remove the tip
                        self.removeTips { $0 is SubscriptionAvailableTip }
                    } else {
                        // If the tip already exists, update it
                        if self.updateTip(ofType: SubscriptionAvailableTip.self, updating: {
                            $0.updateCollection(results)
                        }) == 0 {
                            let tip = SubscriptionAvailableTip(results)
                            self.addTip(tip)
                        }
                    }
                    self._subscribedAnimeNotificationRetrivalTask = nil
                }
        }
    }
}
