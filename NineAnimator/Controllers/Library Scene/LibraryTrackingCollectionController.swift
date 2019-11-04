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

class LibraryTrackingCollectionController: UICollectionViewController, ContentProviderDelegate, UICollectionViewDelegateFlowLayout {
    private var collection: LibrarySceneController.Collection?
    private var cachedCollectionReferences = [Int: [ListingAnimeReference]]()
    private var selectedReference: ListingAnimeReference?
    private var referencesToContextsMap = [ListingAnimeReference: [TrackingContext]]()
    private var referencesMappingQueue = DispatchQueue.global()
    private lazy var layoutHelper = MinFilledFlowLayoutHelper(
        dataSource: self,
        alwaysFillLine: false,
        minimalSize: .init(width: 300, height: 130)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the collection view with approperite settigns
        layoutHelper.configure(collectionView: collectionView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard collection != nil else {
            return Log.error("[LibraryTrackingCollectionController] Collection has not been set while the view is already appearing. Has this controller been initialized?")
        }
        
        // Set delegate
        collection!.delegate = self
        
        // Start loading pages
        if collection!.availablePages == 0 {
            collection!.more()
        } else if cachedCollectionReferences.count != collection!.availablePages {
            // Update the collection references
            cachedCollectionReferences = Dictionary(uniqueKeysWithValues: (0..<collection!.availablePages).map {
                ($0, collection!.links(on: $0).compactMap {
                    switch $0 {
                    case let .listingReference(reference): return reference
                    default: return nil
                    }
                })
            })
            collectionView.reloadData()
        }
    }
}

// MARK: - Init & Data Loading
extension LibraryTrackingCollectionController {
    /// Initialize this controller with a tracking collection
    func setPresenting(_ trackingCollection: LibrarySceneController.Collection) {
        self.collection = trackingCollection
        self.title = trackingCollection.title
    }
    
    func pageIncoming(_ page: Int, from provider: ContentProvider) {
        // Cache collection references
        let cachedPageReferences = provider.links(on: page).compactMap {
            genericLink -> ListingAnimeReference? in
            switch genericLink {
            case let .listingReference(reference): return reference
            default: return nil
            }
        }
        
        // Send the approperiate messages to the collection view
        collectionView.performBatchUpdates({
            // Check whether there are sections before the incoming sections
            // that hasn't been loaded
            var insertingSections = [Int]()
            for section in (0..<page) where cachedCollectionReferences[section] == nil {
                cachedCollectionReferences[section] = []
                insertingSections.append(section)
            }
            
            if cachedCollectionReferences[page] == nil {
                insertingSections.append(page)
                cachedCollectionReferences[page] = cachedPageReferences
                collectionView.insertSections(IndexSet(insertingSections))
            } else {
                // Send insert sections message first
                if !insertingSections.isEmpty {
                    collectionView.insertSections(IndexSet(insertingSections))
                }
                
                // Then reload the section
                cachedCollectionReferences[page] = cachedPageReferences
                collectionView.reloadSections([ page ])
            }
        }, completion: nil)
        
        // Load related contexts
        fetchTrackingContexts(forReferencesOnPage: page)
    }
    
    func onError(_ error: Error, from provider: ContentProvider) {
        Log.error("[LibraryTrackingCollectionController] Received error from Collection Source: @%", error)
    }
    
    private func fetchTrackingContexts(forReferencesOnPage page: Int) {
        guard let references = cachedCollectionReferences[page] else {
            return
        }
        
        // Asynchronously execute the mapping task to prevent blocking the main thread
        referencesMappingQueue.async {
            [weak self] in
            // Fetch the contexts related to the references
            var additionalReferencesMap = [ListingAnimeReference: [TrackingContext]]()
            for reference in references {
                additionalReferencesMap[reference] = NineAnimator.default.trackingContexts(containingReference: reference)
            }
            
            // Synchronously save the fetched contexts to the global map
            DispatchQueue.main.sync {
                guard let self = self else { return }
                self.referencesToContextsMap = additionalReferencesMap
                    .reduce(into: self.referencesToContextsMap) {
                        $0[$1.key] = $1.value
                    }
                self.didResolveAdditonalReferencesMap()
            }
        }
    }
    
    private func didResolveAdditonalReferencesMap() {
        // Only update visible items
        for visibleCellIndex in collectionView.indexPathsForVisibleItems {
            guard let visibleCell = collectionView.cellForItem(at: visibleCellIndex),
                let reference = reference(at: visibleCellIndex),
                let contexts = referencesToContextsMap[reference] else {
                continue
            }
            
            // Call the didResolve methods of the cells to update the subtitle tag
            if let visibleCell = visibleCell as? LibraryTrackingReferenceCell {
                visibleCell.didResolve(relatedTrackingContexts: contexts)
            } else if let visibleCell = visibleCell as? LibraryUntrackedReferenceCell {
                visibleCell.didResolve(relatedTrackingContexts: contexts)
            }
        }
    }
}

// MARK: - Data Source & Delegate
extension LibraryTrackingCollectionController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return cachedCollectionReferences.count
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let collection = collection, collection.moreAvailable {
            let height = scrollView.frame.size.height
            let contentYoffset = scrollView.contentOffset.y
            let distanceFromBottom = scrollView.contentSize.height - contentYoffset
            
            // Try to load more pages if we're too close to the bottom
            if distanceFromBottom < (2.5 * height) {
                collection.more()
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cachedCollectionReferences[section]?.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Obtain the reference from the cached pool
        guard let reference = reference(at: indexPath) else {
            Log.error("[LibraryTrackingCollectionController] UI component tried to load a reference that does not exists: %@", indexPath)
            return UICollectionViewCell()
        }
        let relatedContexts = referencesToContextsMap[reference]
        
        // If this is a tracking anime
        if let tracking = reference.parentService.progressTracking(for: reference) {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "collection.tracking",
                for: indexPath
            ) as! LibraryTrackingReferenceCell
            cell.setPresenting(reference, tracking: tracking, delegate: self)
            
            // If related contexts have been resolved
            if let contexts = relatedContexts {
                cell.didResolve(relatedTrackingContexts: contexts)
            }
            
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "collection.untracked",
                for: indexPath
            ) as! LibraryUntrackedReferenceCell
            cell.setPresenting(reference, delegate: self)
            
            // If related contexts have been resolved
            if let contexts = relatedContexts {
                cell.didResolve(relatedTrackingContexts: contexts)
            }
            
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return layoutHelper.collectionView(collectionView, layout: layout, sizeForItemAt: indexPath)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let reference = self.reference(at: indexPath),
            let cell = collectionView.cellForItem(at: indexPath) else {
            return Log.error("[LibraryTrackingCollectionController] Reference does not exists at %@", indexPath)
        }
        
        self.selectedReference = reference
        self.performSegue(withIdentifier: "collection.information", sender: cell)
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        cell.makeThemable()
    }
}

extension LibraryTrackingCollectionController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? AnimeInformationTableViewController,
            let reference = self.selectedReference {
            destination.setPresenting(reference: reference)
        }
    }
}

// MARK: - Helper Methods
extension LibraryTrackingCollectionController {
    func reference(at indexPath: IndexPath) -> ListingAnimeReference? {
        return cachedCollectionReferences[indexPath.section]?[indexPath.item]
    }
}
