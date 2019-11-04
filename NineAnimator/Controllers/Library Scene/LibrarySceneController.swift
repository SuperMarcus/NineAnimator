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

class LibrarySceneController: MinFilledCollectionViewController {
    /// List of collection providers
    private lazy var collectionProviders: [CollectionSource] = NineAnimator.default.trackingServices
    
    /// List of categories
    private(set) var categories = [Category]()
    
    /// States of each collections
    private lazy var collectionStates = [Result<[Collection], Error>?](
        repeating: nil,
        count: self.collectionProviders.count
    )
    
    /// Hold references to the loading tasks
    private lazy var collectionLoadingTasks = [NineAnimatorAsyncTask?](
        repeating: nil,
        count: self.collectionProviders.count
    )
    
    /// The category that is currently selected by the user
    private var selectedCategory: Category?
    
    /// The collection that is currently being selected
    private var selectedCollection: Collection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the Min Filled Layout
        setLayoutParameters(
            alwaysFillLine: true,
            minimalSize: .init(width: 140, height: 90),
            .init(width: 300, height: 56)
        )
        
        // Configure scroll edge appearance so it looks a little better?
        if #available(iOS 13.0, *) {
            let edgeAppearance = UINavigationBarAppearance()
            edgeAppearance.configureWithTransparentBackground()
            navigationItem.scrollEdgeAppearance = edgeAppearance
        }
        
        initializeCategories()
        loadCollections(failedOnly: false)
    }
}

// MARK: - Data Loading
extension LibrarySceneController {
    /// Load either all collections or those that needs reloading
    private func loadCollections(failedOnly: Bool = true) {
        for i in 0..<collectionProviders.count where collectionProviders[i].shouldPresentInLibrary {
            if !failedOnly {
                reloadFromSource(atOffset: i)
            } else if let currentState = collectionStates[i] {
                switch currentState {
                case .failure: reloadFromSource(atOffset: i)
                default: continue
                }
            } else if collectionLoadingTasks[i] == nil {
                reloadFromSource(atOffset: i)
            }
        }
    }
    
    /// Reload collections from the tracking service at the offset
    private func reloadFromSource(atOffset offset: Int) {
        guard collectionProviders[offset].shouldPresentInLibrary else {
            return
        }
        
        collectionLoadingTasks[offset] = collectionProviders[offset]
            .collections()
            .dispatch(on: .main)
            .error {
                [weak self] in
                self?.collectionStates[offset] = .failure($0)
                self?.onStatesUpdate(forSourceAtOffset: offset)
            } .finally {
                [weak self] in
                self?.collectionStates[offset] = .success($0)
                self?.onStatesUpdate(forSourceAtOffset: offset)
            }
    }
    
    /// Receiving update notification
    private func onStatesUpdate(forSourceAtOffset offset: Int) {
        collectionView.reloadSections([
            sectionIndex(forCollectionSource: offset)
        ])
    }
}

// MARK: - Data Source
extension LibrarySceneController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return numberOfSections
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section.from(section) {
        case .categories: return categories.count
        case .collection:
            if let state = collectionState(forSection: section) {
                switch state {
                case let .success(collections):
                    return collections.count
                default: break
                }
            }
            return 0
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section.from(indexPath.section) {
        case .categories:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "library.categories.category",
                for: indexPath
            ) as! LibraryCategoryCell
            cell.setPresenting(categories[indexPath.item])
            return cell
        case .collection:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "library.collections.collection",
                for: indexPath
            ) as! LibraryCollectionCell
            
            if let collection = collection(atPath: indexPath) {
                cell.setPresenting(collection)
            }
            
            return cell
        }
    }
}

// MARK: - Delegate
extension LibrarySceneController {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        switch Section.from(section) {
        case .categories: return .zero
        case .collection:
            let provider = collectionSource(forSection: section)
            return provider.shouldPresentInLibrary ? .init(
                width: collectionView.bounds.width,
                height: defaultCollectionHeaderHeight
            ) : .zero
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return .zero
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        switch Section.from(section) {
        case .categories: return 15
        case .collection: return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        switch Section.from(section) {
        case .categories: return 15
        case .collection: return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        switch Section.from(section) {
        case .categories: return .init(top: 10, left: 10, bottom: 10, right: 10)
        case .collection: return .init(top: 0, left: 10, bottom: 5, right: 10)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let cell = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "library.collections.header",
            for: indexPath
        ) as! LibraryCollectionsHeaderView
        
        switch Section.from(indexPath.section) {
        case .categories: break
        case .collection:
            let collectionProvider = collectionSource(forSection: indexPath.section)
            cell.setPresenting(collectionProvider)
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? LibraryCollectionCell {
            if let cellParameters = layoutHelper.layoutParameters(forIndex: indexPath) {
                cell.updateApperance(baseOff: cellParameters)
            }
        }
        
        cell.makeThemable()
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if elementKind == UICollectionView.elementKindSectionHeader,
            let view = view as? LibraryCollectionsHeaderView {
            view.updateState(collectionState(forSection: indexPath.section))
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else {
            return Log.error("[LibrarySceneController] Index %@ does not correspond to a visible cell", indexPath)
        }

        switch Section.from(indexPath.section) {
        case .categories:
            let category = categories[indexPath.item]
            self.selectedCategory = category
            performSegue(withIdentifier: category.segueIdentifier, sender: cell)
        case .collection:
            let collection = self.collection(atPath: indexPath)
            self.selectedCollection = collection
            performSegue(withIdentifier: "library.collection", sender: cell)
        }
    }
    
    func minFilledLayout(_ collectionView: UICollectionView, didLayout indexPath: IndexPath, withParameters parameters: MinFilledFlowLayoutHelper.LayoutParameters) {
        if let cell = collectionView.cellForItem(at: indexPath) as? LibraryCollectionCell {
            cell.updateApperance(baseOff: parameters)
        }
    }
}

// MARK: - Segue
extension LibrarySceneController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Initialize the dst controller with the selected collection
        if let destination = segue.destination as? LibraryTrackingCollectionController,
            let collection = self.selectedCollection {
            destination.setPresenting(collection)
        }
        
        // Initialize the dst controller with the selected
        if let destination = segue.destination as? LibraryCategoryReceiverController,
            let category = self.selectedCategory {
            destination.setPresenting(category)
        }
    }
}

// MARK: - Constants & Configurations
extension LibrarySceneController {
    /// An alias of the `ListingService`
    typealias CollectionSource = ListingService
    
    /// An alias of the `ListingAnimeCollection`
    typealias Collection = ListingAnimeCollection
    
    /// The enumeration representing the different types of sections in the Library
    ///
    /// This section is different from the `SectionProtocol` used in the other
    /// table view controllers.
    enum Section: Int {
        /// The categories listed at the first section of the Library
        case categories
        
        /// Collections from the `TrackingService`s
        case collection
        
        /// Retrieve the section from `IndexPath.section`
        static func from(_ section: Int) -> Section {
            if let eSection = Section(rawValue: section) {
                return eSection
            } else { return .collection }
        }
    }
    
    /// Definition of categories
    class Category: Equatable {
        /// Offset of the category
        let offset: Int
        
        /// Label of the category
        let name: String
        
        /// The segue that this category triggers when tapped
        let segueIdentifier: String
        
        /// Icon for this category
        let icon: UIImage
        
        /// Retriever of the marker
        let markerRetriever: () -> String
        
        /// Tinting
        let tintColor: UIColor
        
        /// Getter of the marker. An alias of the marker retriever
        var marker: String { return markerRetriever() }
        
        init(offset: Int, name: String, segueIdentifier: String, tintColor: UIColor, icon: UIImage, markerRetriever: @escaping () -> String) {
            self.offset = offset
            self.name = name
            self.segueIdentifier = segueIdentifier
            self.tintColor = tintColor
            self.icon = icon
            self.markerRetriever = markerRetriever
        }
        
        static func == (lhs: Category, rhs: Category) -> Bool {
            return lhs.offset == rhs.offset
        }
    }
    
    /// Number of sections before the list collections
    var collectionsOffset: Int { return Section.collection.rawValue }
    
    /// The total number of sections
    var numberOfSections: Int { return collectionsOffset + collectionProviders.count }
    
    /// Default row height for cells
    var defaultRowHeight: CGFloat { return 80 }
    
    /// Hight for the collections headers
    var defaultCollectionHeaderHeight: CGFloat { return 50 }
    
    /// Retrieve the CollectionSource for the section
    func collectionSource(forSection section: Int) -> CollectionSource {
        return collectionProviders[section - collectionsOffset]
    }
    
    /// Retrieve the collection's state of loading
    func collectionState(forSection section: Int) -> Result<[Collection], Error>? {
        return collectionStates[section - collectionsOffset]
    }
    
    /// Retrieve the collection at the `indexPath`
    func collection(atPath indexPath: IndexPath) -> Collection? {
        if let state = collectionState(forSection: indexPath.section) {
            switch state {
            case let .success(collections): return collections[indexPath.item]
            default: break
            }
        }
        return nil
    }
    
    /// Retrieve the corresponding section index of the collection source offset
    func sectionIndex(forCollectionSource offset: Int) -> Int {
        return collectionsOffset + offset
    }
    
    /// Initialize the categories collection
    private func initializeCategories() {
        let user = NineAnimator.default.user
        
        // Resets the category list
        categories = []
        
        // Recents
        categories.append(.init(
            offset: categories.count,
            name: "Recents",
            segueIdentifier: "library.category.recents",
            tintColor: #colorLiteral(red: 1, green: 0.6235294118, blue: 0.03921568627, alpha: 1),
            icon: #imageLiteral(resourceName: "History Icon HD")
        ) { "\(user.recentAnimes.count)" })
        
        // Subscribed
        categories.append(.init(
            offset: categories.count,
            name: "Subscribed",
            segueIdentifier: "library.category.subscribed",
            tintColor: #colorLiteral(red: 1, green: 0.2156862745, blue: 0.3725490196, alpha: 1),
            icon: #imageLiteral(resourceName: "Notification Icon HD")
        ) { "\(user.subscribedAnimes.count)" })
        
        // Downloads
        categories.append(.init(
            offset: categories.count,
            name: "Downloads",
            segueIdentifier: "library.category.downloads",
            tintColor: #colorLiteral(red: 0.03921568627, green: 0.5176470588, blue: 1, alpha: 1),
            icon: #imageLiteral(resourceName: "Download Icon HD")
        ) { "\(OfflineContentManager.shared.statefulContents.count)" })
    }
}

fileprivate extension LibrarySceneController.CollectionSource {
    var shouldPresentInLibrary: Bool {
        return self.isCapableOfRetrievingAnimeState
    }
}

/// Controllers that are linked by `LibrarySceneController`'s categories
protocol LibraryCategoryReceiverController {
    /// Initialize the controller with the category
    func setPresenting(_ category: LibrarySceneController.Category)
}
