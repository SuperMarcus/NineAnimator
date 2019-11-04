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

class LibraryRecentsCategoryController: UICollectionViewController, LibraryCategoryReceiverController, UICollectionViewDelegateFlowLayout {
    /// Cached recent anime from `NineAnimatorUser`
    private var cachedRecentAnime = [AnimeLink]()
    
    /// The `AnimeLink` that was selected by the user in the collection view
    private var selectedAnimeLink: AnimeLink?
    
    private lazy var layoutHelper = MinFilledFlowLayoutHelper(
        dataSource: self,
        alwaysFillLine: false,
        minimalSize: .init(width: 300, height: 110)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layoutHelper.configure(collectionView: collectionView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Load Recent Links
        self.reloadRecentLinks()
    }
}

// MARK: - Data Loading
extension LibraryRecentsCategoryController {
    private func reloadRecentLinks() {
        self.cachedRecentAnime = NineAnimator.default.user.recentAnimes
        self.collectionView.reloadData()
    }
}

// MARK: - Data Source & Delegate
extension LibraryRecentsCategoryController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? cachedRecentAnime.count : 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "recents.item",
            for: indexPath
        ) as! LibraryRecentAnimeCell
        cell.setPresenting(cachedRecentAnime[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return layoutHelper.collectionView(collectionView, layout: layout, sizeForItemAt: indexPath)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        selectedAnimeLink = cachedRecentAnime[indexPath.item]
        performSegue(withIdentifier: "recents.player", sender: cell)
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
