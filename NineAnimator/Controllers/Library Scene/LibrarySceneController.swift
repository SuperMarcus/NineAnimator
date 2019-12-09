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
    
    /// List of tips
    private(set) var tips = [Tip]()
    
    /// List of recently watched anime
    private var cachedRecentlyWatchedList = [AnimeLink]()
    
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
    
    /// Background task for loading the most recently watched anime list
    private var recentlyWatchedListLoadingTask: NineAnimatorAsyncTask?
    
    /// Background task for retriving the updated anime
    var _subscribedAnimeNotificationRetrivalTask: NineAnimatorAsyncTask?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the Min Filled Layout
        setLayoutParameters(
            alwaysFillLine: true,
            minimalSize: .init(width: 130, height: 90), // Categories
            .init(width: 300, height: 150), // Tips
            .init(width: 100, height: 170), // Recently Watched
            .init(width: 300, height: 56) // Collections
        )
        
        // Configure scroll edge appearance so it looks a little better?
        configureForTransparentScrollEdge()
        initializeCategories()
        collectionView.makeThemable()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update category cells labbels
        for visibleCell in collectionView.visibleCells {
            if let visibleCell = visibleCell as? LibraryCategoryCell {
                visibleCell.updateLabels()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Update the quick access list to the recently watched anime
        self.reloadRecentAnime()
        self.reloadTips()
        self.reloadCollections(failedOnly: true)
    }
}

// MARK: - Data Loading
extension LibrarySceneController {
    /// Load either all collections or those that needs reloading
    func reloadCollections(failedOnly: Bool = true) {
        for i in 0..<collectionProviders.count {
            if collectionProviders[i].shouldPresentInLibrary {
                // Try to load the collection if it should be present
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
            } else if collectionStates[i] != nil {
                collectionStates[i] = nil
                collectionLoadingTasks[i] = nil
                collectionView.reloadSections([ Section.collection.rawValue ])
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
    
    /// Load the set of recently watched anime
    private func reloadRecentAnime() {
        // Do not attempt to reload if there's an unfinished task
        guard recentlyWatchedListLoadingTask == nil else { return }
        
        // Run the task in the background so it doesn't block the main thread
        recentlyWatchedListLoadingTask = NineAnimatorPromise.firstly {
            [maximalNumberOfRecentlyWatched] () -> [AnimeLink] in
            // Load 6 recently watch anime
            let browsingHistory = NineAnimator.default.user.recentAnimes
            let sortedRecordMap = browsingHistory.compactMap {
                anime -> (AnimeLink, TrackingContext.PlaybackProgressRecord)? in
                let context = NineAnimator.default.trackingContext(for: anime)
                if let record = context.mostRecentRecord {
                    return (anime, record)
                } else { return nil }
            } .sorted { $0.1.enqueueDate > $1.1.enqueueDate }
            return sortedRecordMap[0..<min(maximalNumberOfRecentlyWatched, sortedRecordMap.count)].map {
                $0.0
            }
        } .dispatch(on: .main).error {
            [weak self] error in
            Log.error("[LibrarySceneController] THIS SHOULD NOT HAPPEN - Finished loading recently watched list with an error: %@", error)
            self?.recentlyWatchedListLoadingTask = nil
        } .finally {
            [weak self] results in
            guard let self = self else { return }
            self.cachedRecentlyWatchedList = results
            self.collectionView.reloadSections([ Section.recentlyWatched.rawValue ])
            self.recentlyWatchedListLoadingTask = nil
        }
    }
    
    /// Add and present the tip
    func addTip(_ tip: Tip) {
        tips.insert(tip, at: 0)
        collectionView.insertItems(at: [
            .init(item: 0, section: Section.tips.rawValue)
        ])
    }
    
    /// Remove the tip with the predicate
    func removeTips(where predicate: (Tip) throws -> Bool) rethrows {
        let (
            newTips,
            removingIndices
        ) = try tips.enumerated().reduce(into: ([Tip](), [Int]())) {
            results, tip in
            if try predicate(tip.element) {
                results.1.append(tip.offset)
            } else { results.0.append(tip.element) }
        }
        
        // Update the value and notify the collection view
        self.tips = newTips
        self.collectionView.deleteItems(at: removingIndices.map {
            IndexPath(item: $0, section: Section.tips.rawValue)
        })
    }
    
    /// Remove the tip
    func removeTip(_ tip: Tip) {
        removeTips { $0 == tip }
    }
    
    /// Updating every tip of type T
    ///
    /// - Returns: Number of Tips updated
    func updateTip<T: Tip>(ofType type: T.Type, updating: (T) throws -> Void) rethrows -> Int {
        var reloadingTips = [Int]()
        for (index, tip) in tips.enumerated() {
            if let tip = tip as? T {
                try updating(tip)
                reloadingTips.append(index)
            }
        }
        collectionView.reloadItems(at: reloadingTips.map {
            IndexPath(item: $0, section: Section.tips.rawValue)
        })
        return reloadingTips.count
    }
    
    /// Return the first tip of type T
    func getTip<T: Tip>(ofType type: T.Type) -> T? {
        return tips.first { $0 is T } as? T
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
        case .tips: return tips.count
        case .recentlyWatched: return cachedRecentlyWatchedList.count
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
        case .tips:
            let tip = tips[indexPath.item]
            return tip.setupCell(collectionView, at: indexPath, parent: self)
        case .recentlyWatched:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "library.visited",
                for: indexPath
            ) as! LibraryRecentlyWatchedCell
            cell.setPresenting(cachedRecentlyWatchedList[indexPath.item])
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
    @IBAction private func onCastButtonPressed(_ sender: Any) {
        RootViewController.shared?.showCastController()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        switch Section.from(section) {
        case .categories: return .zero
        case .tips: return .zero
        case .recentlyWatched:
            return cachedRecentlyWatchedList.isEmpty ? .zero : .init(
                width: collectionView.bounds.width,
                height: defaultCollectionHeaderHeight
            )
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
        case .tips: return 10
        case .recentlyWatched: return 10
        case .collection: return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        switch Section.from(section) {
        case .categories: return 15
        case .tips: return 10
        case .recentlyWatched: return 10
        case .collection: return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        switch Section.from(section) {
        case .categories: return .init(top: 10, left: 10, bottom: 10, right: 10)
        case .tips: return .init(top: 5, left: 10, bottom: 10, right: 10)
        case .recentlyWatched: return .init(top: 0, left: 10, bottom: 10, right: 10)
        case .collection: return .init(top: 0, left: 10, bottom: 5, right: 10)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let cell = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "library.collections.header",
            for: indexPath
        ) as! LibraryHeaderView
        
        switch Section.from(indexPath.section) {
        case .tips: break
        case .categories: break
        case .recentlyWatched:
            if !cachedRecentlyWatchedList.isEmpty {
                cell.setPresenting("Recently Watched")
                cell.updateState(isLoading: false)
            }
        case .collection:
            let collectionProvider = collectionSource(forSection: indexPath.section)
            cell.setPresenting(collectionProvider.name)
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? LibraryCollectionCell {
            if let cellParameters = layoutHelper.layoutParameters(forIndex: indexPath, inCollection: collectionView) {
                cell.updateApperance(baseOff: cellParameters)
            }
        }
        
        cell.makeThemable()
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if elementKind == UICollectionView.elementKindSectionHeader,
            Section.from(indexPath.section) == .collection,
            let view = view as? LibraryHeaderView {
            view.updateState(
                isLoading: collectionState(forSection: indexPath.section) == nil
            )
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else {
            return Log.error("[LibrarySceneController] Index %@ does not correspond to a visible cell", indexPath)
        }

        switch Section.from(indexPath.section) {
        case .categories:
            let category = categories[indexPath.item]
            present(category: category)
        case .tips:
            let tip = tips[indexPath.item]
            tip.onSelection(collectionView, at: indexPath, selectedCell: cell, parent: self)
        case .recentlyWatched:
            let anime = cachedRecentlyWatchedList[indexPath.item]
            RootViewController.shared?.open(
                immedietly: .anime(anime),
                in: self
            )
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
    
    func minFilledLayout(_ collectionView: UICollectionView, shouldFillLineForSection section: Int) -> Bool {
        switch Section.from(section) {
        case .recentlyWatched: return false
        case .tips: return false
        default: return true
        }
    }
    
    func minFilledLayout(_ collectionView: UICollectionView, shouldAlignLastLineItemsInSection section: Int) -> Bool {
        switch Section.from(section) {
        case .collection: return true
        default: return false
        }
    }
}

// MARK: - Segue
extension LibrarySceneController {
    /// Present the category
    func present(category: Category, sender: Any? = nil) {
        selectedCategory = category
        performSegue(withIdentifier: category.segueIdentifier, sender: sender)
    }
    
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
        
        /// The section where download progress preview, subscription notifications
        /// and the other tips are located.
        case tips
        
        /// A number of recently watched anime
        case recentlyWatched
        
        /// Collections from the `TrackingService`s
        case collection
        
        /// Retrieve the section from `IndexPath.section`
        static func from(_ section: Int) -> Section {
            if let eSection = Section(rawValue: section) {
                return eSection
            } else { return .collection }
        }
    }
    
    /// A tip that can be shown in the tips section
    class Tip: NSObject {
        /// Setup the tip at the indexPath
        func setupCell(_ collectionView: UICollectionView, at indexPath: IndexPath, parent: LibrarySceneController) -> UICollectionViewCell {
            Log.error("[LibrarySceneController.Tip] Unimplemented method")
            return UICollectionViewCell()
        }
        
        /// Do something when the tip has been selected
        func onSelection(_ collectionView: UICollectionView, at indexPath: IndexPath, selectedCell: UICollectionViewCell, parent: LibrarySceneController) {
            Log.error("[LibrarySceneController.Tip] Unimplemented method")
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
    
    /// Number of recently watched anime to be shown
    var maximalNumberOfRecentlyWatched: Int { return 6 }
    
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
    
    /// Return the category with the segue identifier
    func category(withIdentifier segueIdentifier: String) -> Category? {
        return categories.first { $0.segueIdentifier == segueIdentifier }
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
