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

import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources
import UIKit

extension LibrarySceneController {
    // MARK: - Updated Episode Tip
    class SubscriptionAvailableTip: Tip {
        private var updatedAnimeLinks: [AnimeLink]
        
        fileprivate init(_ updatedAnime: [AnimeLink]) {
            self.updatedAnimeLinks = updatedAnime
            super.init()
        }
        
        fileprivate func updateCollection(_ updated: [AnimeLink]) {
            self.updatedAnimeLinks = updated
        }
        
        override func onSelection(_ collectionView: UICollectionView, at indexPath: IndexPath, selectedCell: UICollectionViewCell, parent: LibrarySceneController) {
            // Open the anime if there's only one that's updated
            if updatedAnimeLinks.count == 1,
                let anime = updatedAnimeLinks.first {
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
            // Obtain a generic cell from the collection view
            let cell =  collectionView.dequeueReusableCell(
                withReuseIdentifier: LibraryTipGenericCell.reuseIdentifier,
                for: indexPath
            ) as! LibraryTipGenericCell
            
            // Generate description based on the number of updated anime available
            let updatedCount = updatedAnimeLinks.count
            let description: String
            if updatedCount == 1,
                let updatedAnime = updatedAnimeLinks.first {
                description = "A new episode of \(updatedAnime.title) is now available. Stream now from \(updatedAnime.source.name)."
            } else {
                description = "\(updatedAnimeLinks.count) anime you've subscribed have new episodes available and \(updatedCount > 1 ? "are" : "is") now available for streaming."
            }
            
            // Initialize the cell with title and description
            cell.setPresenting(title: "New Episodes Available", description: description)
            cell.makeThemable()
            return cell
        }
    }
    
    // MARK: - Connect with Tracking Services
    class ConnectWithTrackingServiceTip: Tip {
        override func onSelection(_ collectionView: UICollectionView, at indexPath: IndexPath, selectedCell: UICollectionViewCell, parent: LibrarySceneController) {
            if let settingsController = SettingsSceneController.create(
                navigatingTo: .trackingService,
                onDismissal: { // This closure should be running in the main thread
                    [weak collectionView, weak parent] in // Needs to handle dismissal by ourself
                    collectionView?.deselectItem(at: indexPath, animated: true)
                    parent?.reloadTips()
                    parent?.reloadCollections()
                }
            ) { parent.present(settingsController, animated: true) }
        }
        
        override func setupCell(_ collectionView: UICollectionView, at indexPath: IndexPath, parent: LibrarySceneController) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: LibraryTipImagedCell.reuseIdentifier,
                for: indexPath
            ) as! LibraryTipImagedCell
            cell.setPresenting(
                image: #imageLiteral(resourceName: "NineAnimator Lists Tip"),
                title: "Connect with Anime Lists",
                imageFillMode: .scaleAspectFill
            )
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
        
        // Connect with tracking service tip
        if NineAnimator.default.trackingServices.reduce(0, {
            $0 + ($1.isCapableOfRetrievingAnimeState ? 1 : 0)
        }) == 0 {
            if self.getTip(ofType: ConnectWithTrackingServiceTip.self) == nil {
                let tip = ConnectWithTrackingServiceTip()
                self.addTip(tip)
            }
        } else { self.removeTips { $0 is ConnectWithTrackingServiceTip } }
    }
}
