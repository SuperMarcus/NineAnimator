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
        
        // Drag and Drop support
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        
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
        
        // Request for notification permissions
        if !cachedWatchedAnimeItems.isEmpty {
            UserNotificationManager.default.requestNotificationPermissions(shouldPresetError: false)
        }
    }
}

// MARK: - Delegate and Data Source
extension LibrarySubscriptionCategoryController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cachedWatchedAnimeItems.count
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
    
    override func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        indexPath.section == 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        self.moveSubscriptionItem(fromIndex: sourceIndexPath.item, toIndex: destinationIndexPath.item)
    }
}

extension LibrarySubscriptionCategoryController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        [ self.makeDragItem(for: self.cachedWatchedAnimeItems[indexPath.item]) ]
    }
    
    private func makeDragItem(for link: AnyLink) -> UIDragItem {
        let attributedText = NSMutableAttributedString(string: link.name)
        attributedText.addAttributes([
            .link: link.cloudRedirectionUrl
        ], range: attributedText.string.matchingRange)
        let itemProvider = NSItemProvider(object: attributedText)
        return UIDragItem(itemProvider: itemProvider)
    }
}

extension LibrarySubscriptionCategoryController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        guard session.items.count == 1 else {
            Log.error("[LibrarySubscriptionCategoryController] Drag session initiated with unexpected number of items: %@", session.items.count)
            return .init(operation: .cancel)
        }
        
        if collectionView.hasActiveDrag {
            return .init(operation: .move, intent: .insertAtDestinationIndexPath)
        } else {
            return .init(operation: .cancel)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let dropItem = coordinator.items.first else {
            return Log.error("[LibrarySubscriptionCategoryController] Cannot perform drop with no drop items.")
        }
        
        guard let destinationIndexPath = coordinator.destinationIndexPath else {
            return Log.error("[LibrarySubscriptionCategoryController] Cannot perform drop with undefined destinationIndexPath.")
        }
        
        switch coordinator.proposal.operation {
        case .move:
            guard let sourceIndexPath = dropItem.sourceIndexPath else {
                return Log.error("[LibrarySubscriptionCategoryController] UIDropOperation.move did not define a source index path.")
            }
            
            self.collectionView.performBatchUpdates({
                self.moveSubscriptionItem(fromIndex: sourceIndexPath.item, toIndex: destinationIndexPath.item)
                self.collectionView.deleteItems(at: [ sourceIndexPath ])
                self.collectionView.insertItems(at: [ destinationIndexPath ])
            }, completion: nil)
            coordinator.drop(dropItem.dragItem, toItemAt: destinationIndexPath)
        default:
            Log.info("[LibrarySubscriptionCategoryController] Unimplemented drop operation %@", coordinator.proposal.operation)
        }
    }
    
    private func moveSubscriptionItem(fromIndex sourceIndex: Int, toIndex destinationIndex: Int) {
        let originalItem = cachedWatchedAnimeItems.remove(at: sourceIndex)
        cachedWatchedAnimeItems.insert(originalItem, at: destinationIndex)
        NineAnimator.default.user.moveSubscription(fromIndex: sourceIndex, toIndex: destinationIndex)
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

extension LibrarySubscriptionCategoryController {
    func unsubscribe(_ link: AnyLink, indexPath: IndexPath? = nil) {
        let correspondingIndex: IndexPath
        
        // Even though we're expecting the index to be valid, just to
        // prevent some werid iOS glitches we'll still do a full check.
        if let knownIndex = indexPath, knownIndex.section == 0,
            (0..<cachedWatchedAnimeItems.count).contains(knownIndex.item) {
            correspondingIndex = knownIndex
        } else if let cachedIndex = cachedWatchedAnimeItems.firstIndex(of: link) {
            correspondingIndex = .init(item: cachedIndex, section: 0)
        } else {
            return Log.error("[LibrarySubscriptionCategoryController] Trying to unsubscribe a link '%@' that doesn't exist in the cache.", link)
        }
        
        if case let .anime(animeLink) = link {
            NineAnimator.default.user.unsubscribe(anime: animeLink)
            cachedWatchedAnimeItems.remove(at: correspondingIndex.item)
            collectionView.deleteItems(at: [ correspondingIndex ])
        }
    }
}

// MARK: - Context Menus
extension LibrarySubscriptionCategoryController {
    @available(iOS 13.0, *)
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let sourceCell = collectionView.cellForItem(at: indexPath) as? LibrarySubscriptionCell,
            let relatedLink = sourceCell.representingLink else {
            return nil
        }
        
        return .init(
            identifier: nil,
            previewProvider: nil
        ) { [weak self] _ -> UIMenu? in
            var menuItems = [UIAction]()
            
            menuItems.append(.init(
                title: "Unsubscribe", // Get to use SFSymbols here because >= iOS 13 !!
                image: UIImage(systemName: "bell.slash.fill"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.unsubscribe(relatedLink, indexPath: indexPath)
            })
            
            menuItems.append(.init(
                title: "Share",
                image: UIImage(systemName: "square.and.arrow.up")
            ) { [weak self] _ in
                guard let self = self else { return }

                // Present the share sheet
                RootViewController.shared?.presentShareSheet(
                    forLink: relatedLink,
                    from: sourceCell,
                    inViewController: self
                )
            })
            
            return UIMenu(
                title: "Subscribed Anime",
                children: menuItems
            )
        }
    }
}
