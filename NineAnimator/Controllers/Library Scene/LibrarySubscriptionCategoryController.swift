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

class LibrarySubscriptionCategoryController: MinFilledCollectionViewController, LibraryCategoryReceiverController {
    private var cachedWatchedAnimeItems = [AnyLink]()
    private var subscriptionUpdateContainer: StatefulAsyncTaskContainer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize Min Filled Layout
        setLayoutParameters(
            alwaysFillLine: false,
            minimalSize: .init(width: 300, height: 110)
        )
        
        // Perform fetch request and update cells
        subscriptionUpdateContainer = StatefulAsyncTaskContainer {
            [weak self] _ in DispatchQueue.main.async {
                guard let self = self else { return }
                for cell in self.collectionView.visibleCells {
                    if let cell = cell as? LibrarySubscriptionCell {
                        cell.updateSubtitleInformation()
                    }
                }
            }
        }
        UserNotificationManager.default.performFetch(within: subscriptionUpdateContainer!)
        subscriptionUpdateContainer?.collect()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        cachedWatchedAnimeItems = NineAnimator.default.user.subscribedAnimes.map {
            .anime($0)
        }
        collectionView.reloadData()
    }
}

// MARK: - Delegate and Data Source
extension LibrarySubscriptionCategoryController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cachedWatchedAnimeItems.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "subscribed.cell",
            for: indexPath
        ) as! LibrarySubscriptionCell
        let link = cachedWatchedAnimeItems[indexPath.item]
        cell.setPresenting(link)
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? LibrarySubscriptionCell {
            cell.updateSubtitleInformation()
        }
        cell.makeThemable()
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let link = cachedWatchedAnimeItems[indexPath.item]
        RootViewController.shared?.open(immedietly: link, in: self)
    }
}

// MARK: - Initialization
extension LibrarySubscriptionCategoryController {
    func setPresenting(_ category: LibrarySceneController.Category) {
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.largeTitleTextAttributes[.foregroundColor] = category.tintColor
            navigationItem.scrollEdgeAppearance = appearance
        }
    }
}
