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
