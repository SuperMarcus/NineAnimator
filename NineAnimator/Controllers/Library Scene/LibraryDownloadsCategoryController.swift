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

class LibraryDownloadsCategoryController: MinFilledCollectionViewController, LibraryCategoryReceiverController {
    private var statefulAnimeMap = [AnimeLink]()
    
    private var selectedAnimeLink: AnimeLink?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize Min Filled Layout
        setLayoutParameters(
            alwaysFillLine: false,
            minimalSize: .init(width: 300, height: 110)
        )
        
        // Listen to state update
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onOfflineProgressUpdate(_:)),
            name: .offlineAccessStateDidUpdate,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.reloadStatefulAnime()
    }
    
    fileprivate func reloadStatefulAnime() {
        // Initialize stateful anime pool
        let currentStatefulLinks = OfflineContentManager.shared.statefulAnime
        let shouldAnimate = statefulAnimeMap.count != currentStatefulLinks.count
        statefulAnimeMap = currentStatefulLinks
        
        // Animate/reload collection view
        if shouldAnimate {
            collectionView.reloadSections([ 0 ])
        } else { collectionView.reloadData() }
    }
}

// MARK: - Data Fetching
extension LibraryDownloadsCategoryController {
    func updateStatefulAnime() {
        statefulAnimeMap = OfflineContentManager.shared.statefulAnime
    }
    
    @objc private func onOfflineProgressUpdate(_ notification: Notification) {
        DispatchQueue.main.async {
            [weak self] in
            // Obtain the `OfflineEpisodeContent` object
            guard let content = notification.object as? OfflineEpisodeContent,
                let self = self else {
                return
            }
            
            // Only updating cells that are visible
            let correspondingStatefulAnimeLink = content.episodeLink.parent
            for cell in self.collectionView.visibleCells {
                if let cell = cell as? LibraryDownloadingAnimeCell,
                    cell.animeLink == correspondingStatefulAnimeLink {
                    cell.updateStates()
                }
            }
        }
    }
}

// MARK: - Data Source & Delegate
extension LibraryDownloadsCategoryController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? statefulAnimeMap.count : 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "downloads.cell",
            for: indexPath
        ) as! LibraryDownloadingAnimeCell
        cell.setPresenting(statefulAnimeMap[indexPath.item])
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        selectedAnimeLink = statefulAnimeMap[indexPath.item]
        performSegue(withIdentifier: "downloads.show", sender: cell)
    }
}

// MARK: - Navigation
extension LibraryDownloadsCategoryController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Initialize the OfflineAnimeViewController
        if let destination = segue.destination as? OfflineAnimeViewController,
            let selectedAnimeLink = selectedAnimeLink {
            destination.setPresenting(anime: selectedAnimeLink)
        }
    }
    
    @IBAction private func onManageButtonDidPressed(_ sender: Any) {
        let vc = SettingsSceneController.create(navigatingTo: .storage) {
            [weak self] in self?.reloadStatefulAnime()
        }
        if let vc = vc {
            present(vc, animated: true)
        }
    }
}

// MARK: - Initialization
extension LibraryDownloadsCategoryController {
    func setPresenting(_ category: LibrarySceneController.Category) {
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.largeTitleTextAttributes[.foregroundColor] = category.tintColor
            navigationItem.scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Context Menu & Editing
extension LibraryDownloadsCategoryController {
    /// For iOS 13.0 and higher, use the built-in `UIContextMenu` for operations
    @available(iOS 13.0, *)
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let sourceCell = collectionView.cellForItem(at: indexPath) else {
            return nil
        }
        
        let relatedAnimeLink = statefulAnimeMap[indexPath.item]
        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil
        ) { [weak self, weak sourceCell] _ -> UIMenu? in
            var menuItems = [UIAction]()
            
            // Obtain the contents
            let contents = OfflineContentManager.shared.contents(for: relatedAnimeLink)
            let animationDelay = DispatchTimeInterval.seconds(1)
            
            menuItems.append(.init(
                title: "Remove Downloads",
                image: UIImage(systemName: "trash.fill"),
                identifier: nil,
                attributes: [.destructive]
            ) { _ in DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
                    self?.confirmRemovingEpisodes(
                        ofAnimeLink: relatedAnimeLink,
                        from: sourceCell
                    )
                }
            })
            
            let isPreservingFilter: (OfflineContent) -> Bool = {
                switch $0.state {
                case .preserving, .preservationInitiated: return true
                default: return false
                }
            }
            
            let isSuspendedFilter: (OfflineContent) -> Bool = {
                switch $0.state {
                case .interrupted: return true
                default: return false
                }
            }
            
            // Suspend preserving downloads
            if contents.contains(where: isPreservingFilter) {
                menuItems.append(.init(
                    title: "Pause Downloads",
                    image: UIImage(systemName: "pause.fill"),
                    identifier: nil
                ) { _ in
                    // Only suspend preserving and queued contents
                    let preservingContents = contents.filter(isPreservingFilter)
                    OfflineContentManager.shared.suspendPreservations(contents: preservingContents)
                })
            }
            
            // Resume suspended downloads
            if contents.contains(where: isSuspendedFilter) {
                menuItems.append(.init(
                    title: "Resume Downloads",
                    image: UIImage(systemName: "play.fill"),
                    identifier: nil
                ) { _ in
                    // Only suspend preserving and queued contents
                    let preservingContents = contents.filter(isSuspendedFilter)
                    preservingContents.forEach {
                        OfflineContentManager.shared.initiatePreservation(content: $0)
                    }
                })
            }

            return UIMenu(
                title: "Selected Anime",
                identifier: nil,
                options: [],
                children: menuItems
            )
        }
    }
    
    private func confirmRemovingEpisodes(ofAnimeLink animeLink: AnimeLink, from sourceView: UIView?) {
        let presentationStyle: UIAlertController.Style = sourceView == nil
            ? .alert : .actionSheet
        let alert = UIAlertController(
            title: "Delete Downloaded Episodes",
            message: "Confirm you want to delete all downloads of \(animeLink.title). You won't be able to recover any of the episodes unless you re-download them.",
            preferredStyle: presentationStyle
        )
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sourceView
        }
        
        alert.addAction(.init(
            title: "Delete Episodes",
            style: .destructive
        ) { [weak self] _ in
            OfflineContentManager.shared.cancelPreservations(forEpisodesOf: animeLink)
            DispatchQueue.main.async { self?.reloadStatefulAnime() }
        })
        
        alert.addAction(.init(
            title: "Cancel",
            style: .cancel
        ))
        
        present(alert, animated: true)
    }
}
