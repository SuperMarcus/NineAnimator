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

import CoreData
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources
import UIKit

class LibraryRecentsCategoryController: MinFilledCollectionViewController, LibraryCategoryReceiverController, NSFetchedResultsControllerDelegate {
    /// The `AnimeLink` that was selected by the user in the collection view
    private var selectedAnimeLink: AnimeLink?
    
    /// The `IndexPath` that is currently used by the menu controller
    private var menuIndexPath: IndexPath?
    
    private var dataSource: NACoreDataDataSource<NACoreDataLibraryRecord>?
    
    /// Main context
    private var dataContext: NACoreDataLibrary.Context {
        NineAnimator.default.user.coreDataLibrary.mainContext
    }
    
    /// Needs to be able to become the first responder
    override var canBecomeFirstResponder: Bool { true }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure data source
        let resultsController = dataContext.fetchRecentsController()
        let dataSource = NACoreDataDataSource(resultsController)
        self.dataSource = dataSource
        
        dataSource.configure(collectionView: collectionView) {
            collectionView, _, indexPath, record in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "recents.item",
                for: indexPath
            ) as! LibraryRecentAnimeCell
            
            if case let .some(.anime(recordAnimeLink)) = record.link?.nativeAnyLink {
                cell.setPresenting(recordAnimeLink)
            }
            
            return cell
        }
        
        // Initialize Min Filled Layout
        setLayoutParameters(
            alwaysFillLine: false,
            minimalSize: .init(width: 300, height: 110)
        )
        
        // Fetch data
        dataSource.fetch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
}

// MARK: - Delegate
extension LibraryRecentsCategoryController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath),
            case let .anime(animeLink) = dataSource?.object(at: indexPath).link?.nativeAnyLink else { return }
        selectedAnimeLink = animeLink
        performSegue(withIdentifier: "recents.player", sender: cell)
    }
}

// MARK: - Data Loading
extension LibraryRecentsCategoryController {
    /// Remove the anime from the recents anime list
    private func removeAnime(atIndex indexPath: IndexPath) {
        if let record = self.dataSource?.object(at: indexPath) {
            do {
                try dataContext.removeLibraryRecord(record: record)
            } catch {
                Log.error("[LibraryRecentsCategoryController] Unable to remove record: %@.", error)
            }
        }
    }
}

// MARK: - Initialization
extension LibraryRecentsCategoryController {
    func setPresenting(_ category: LibrarySceneController.Category) {
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.largeTitleTextAttributes[.foregroundColor] = category.tintColor
            navigationItem.scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Navigation
extension LibraryRecentsCategoryController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Initialize the anime viewer
        if let destination = segue.destination as? AnimeViewController,
            let selectedAnimeLink = selectedAnimeLink {
            destination.setPresenting(anime: selectedAnimeLink)
        }
    }
}

// MARK: - Context Menu & Editing
extension LibraryRecentsCategoryController {
    /// For iOS 13.0 and higher, use the built-in `UIContextMenu` for operations
    @available(iOS 13.0, *)
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let managedLibraryRecord = self.dataSource?.object(at: indexPath),
            case let .some(.anime(relatedAnimeLink)) = managedLibraryRecord.link?.nativeAnyLink else {
            return nil
        }
        
        let animationWaitTime: DispatchTimeInterval = .milliseconds(300)
        let configuration = UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil) {
                [weak self] _ -> UIMenu? in
                var menuItems = [UIAction]()
                
                // Subscription
                if NineAnimator.default.user.isSubscribing(anime: relatedAnimeLink) {
                    menuItems.append(.init(
                        title: "Unsubscribe",
                        image: UIImage(systemName: "bell.slash.fill"),
                        identifier: nil
                    ) { _ in NineAnimator.default.user.unsubscribe(anime: relatedAnimeLink) })
                } else {
                    menuItems.append(.init(
                        title: "Subscribe",
                        image: UIImage(systemName: "bell.fill"),
                        identifier: nil
                    ) { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + animationWaitTime) {
                            // Request permission first
                            UserNotificationManager.default.requestNotificationPermissions()
                            NineAnimator.default.user.subscribe(uncached: relatedAnimeLink)
                        }
                    })
                }
                
                // Share
                menuItems.append(.init(
                    title: "Share",
                    image: UIImage(systemName: "square.and.arrow.up"),
                    identifier: nil
                ) { _ in
                    // Wait for 0.5 second until presenting
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationWaitTime) {
                        guard let self = self,
                            let cell = self.collectionView.cellForItem(at: indexPath) else {
                                return
                        }
                        
                        // Present the share sheet
                        RootViewController.shared?.presentShareSheet(
                            forLink: .anime(relatedAnimeLink),
                            from: cell,
                            inViewController: self
                        )
                    }
                })
                
                // Remove
                menuItems.append(.init(
                    title: "Remove from Recents",
                    image: UIImage(systemName: "trash.fill"),
                    identifier: nil,
                    attributes: [ .destructive ]
                ) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationWaitTime) {
                        self?.removeAnime(atIndex: indexPath)
                    }
                })
                
                return UIMenu(
                    title: "Selected Anime",
                    identifier: nil,
                    options: [],
                    children: menuItems
                )
            }
        return configuration
    }
    
    @IBAction private func onLongPressGestureRegconized(_ sender: UILongPressGestureRecognizer) {
        if #available(iOS 13.0, *) {
            // Not doing anything for iOS 13.0+ since
            // actions are presented with context menus
        } else if sender.state == .began {
            let location = sender.location(in: collectionView)
            // Obtain the cell
            if let indexPath = collectionView.indexPathForItem(at: location),
                let cell = collectionView.cellForItem(at: indexPath) as? LibraryRecentAnimeCell {
                self.becomeFirstResponder()
                
                self.menuIndexPath = indexPath
                let targetRect = collectionView.convert(cell.frame, to: view)
                let editMenu = UIMenuController.shared
                var availableMenuItems = [UIMenuItem]()
                
                // Remove operation
                availableMenuItems.append(.init(
                    title: "Remove",
                    action: #selector(menuController(removeLink:))
                ))
                
                // Save the available actions
                editMenu.menuItems = availableMenuItems
                editMenu.setTargetRect(targetRect, in: view)
                editMenu.setMenuVisible(true, animated: true)
            }
        }
    }
    
    @objc private func menuController(removeLink sender: UIMenuController) {
        if let menuIndexPath = menuIndexPath {
            removeAnime(atIndex: menuIndexPath)
        }
    }
}
