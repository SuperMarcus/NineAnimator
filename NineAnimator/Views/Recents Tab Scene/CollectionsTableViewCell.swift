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

class CollectionsTableViewCell: UITableViewCell, Themable, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate {
    @IBOutlet private weak var collectionView: UICollectionView!
    
    /// Third party anime tracking service lists
    private var listingServiceCollections = [ListingAnimeCollection]()
    
    /// References to async tasks
    private var taskReferencePool = [NineAnimatorAsyncTask]()
    
    private var onLayout: (() -> Void)?
    
    private var indexOfCellBeforeDragging = 0
    
    private let maxCellWidth: CGFloat = 400
    
    private let enablePaging = true

    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    func setupCollectionsCell(_ layoutHandler: @escaping () -> Void) {
        onLayout = layoutHandler
        reloadListingServiceCollections()
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return listingServiceCollections.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "collection", for: indexPath) as! RecentsSceneCollectionCollectionViewCell
        cell.setPresenting(listingServiceCollections[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? RecentsSceneCollectionCollectionViewCell)?.willDisplay()
        cell.alpha = 0
        UIView.animate(withDuration: 0.1) { cell.alpha = 1.0 }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(
            width: min(maxCellWidth, collectionView.bounds.width),
            height: collectionView.bounds.height
        )
    }

    func theme(didUpdate theme: Theme) {
        backgroundColor = .clear
    }
    
    private func collectReferencePoolGarbages() {
        taskReferencePool.removeAll { ($0 as? NineAnimatorPromiseProtocol)?.isResolved ?? false }
    }
    
    private func reloadListingServiceCollections() {
        for service in NineAnimator.default.trackingServices where service.isCapableOfRetrievingAnimeState {
            let task = service.collections().error {
                [unowned service] in
                Log.error("Did not load lists from service \"%@\": %@", service.name, $0)
                } .finally {
                    [weak self, unowned service] collections in
                    DispatchQueue.main.async {
                        [unowned service] in
                        guard let self = self else { return }
                        
                        // Use a batch update block
                        self.collectionView.performBatchUpdates({
                            // First, update all collections that did not
                            // appear again in the latest collections
                            var variableCollections = collections
                            var indexesToDelete = [Int]()
                            
                            for (index, collection) in self.listingServiceCollections.enumerated()
                                where collection.parentService.name == service.name {
                                    // If the collection exists in the presented collections,
                                    // just update the value without notifying tableview
                                    if let (sourceIndex, newCollection) = variableCollections
                                        .enumerated()
                                        .first(where: { $0.element.title == collection.title }) {
                                        // Remove the collection from the source
                                        _ = variableCollections.remove(at: sourceIndex)
                                        self.listingServiceCollections[index] = newCollection
                                    } else {
                                        // Else, mark this row as deleted and remove it from
                                        // the listing service collections
                                        indexesToDelete.append(index)
                                    }
                            }
                            
                            // Remove all marked-to-remove elements
                            self.listingServiceCollections = self.listingServiceCollections
                                .enumerated()
                                .filter { !indexesToDelete.contains($0.offset) }
                                .map { $0.element }
                            
                            // Send remove message to table view
                            self.collectionView.deleteItems(
                                at: indexesToDelete.map { IndexPath(item: $0, section: 0) }
                            )
                            
                            // Since the use will likely be used to have collections grouped
                            // together by the services, find the index of the first occurance
                            // and insert it from there
                            let insertingIndex = self.listingServiceCollections
                                .enumerated()
                                .first { $0.element.parentService.name == service.name }?
                                .offset ?? 0
                            
                            // Make the insertion
                            variableCollections.forEach {
                                self.listingServiceCollections.insert($0, at: insertingIndex)
                            }
                            
                            // Tell the table view that we have made those insertions
                            self.collectionView.insertItems(
                                at: (insertingIndex..<(insertingIndex + variableCollections.count))
                                    .map { IndexPath(item: $0, section: 0) }
                            )
                        }, completion: nil)
                    }
            }
            taskReferencePool.append(task)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Remove seperator
        separatorInset = .init(top: 0, left: bounds.width / 2, bottom: 0, right: bounds.width / 2)
    }
}

extension CollectionsTableViewCell {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        indexOfCellBeforeDragging = collectionView.indexPathsForVisibleItems.first!.item
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // Disable snapping if there are more than one cells in a page
        guard enablePaging && collectionView.bounds.width <= maxCellWidth else { return }
        
        // Stop scrolling
        targetContentOffset.pointee = scrollView.contentOffset
        
        // Calculate conditions
        let pageWidth = collectionView.bounds.width + 40
        let collectionViewItemCount = collectionView(collectionView, numberOfItemsInSection: 0)// The number of items in this section
        let proportionalOffset = collectionView.contentOffset.x / pageWidth
        let indexOfMajorCell = Int(round(proportionalOffset))
        let swipeVelocityThreshold: CGFloat = 0.5
        let hasEnoughVelocityToSlideToTheNextCell = indexOfCellBeforeDragging + 1 < collectionViewItemCount && velocity.x > swipeVelocityThreshold
        let hasEnoughVelocityToSlideToThePreviousCell = indexOfCellBeforeDragging - 1 >= 0 && velocity.x < -swipeVelocityThreshold
        let majorCellIsTheCellBeforeDragging = indexOfMajorCell == indexOfCellBeforeDragging
        let didUseSwipeToSkipCell = majorCellIsTheCellBeforeDragging && (hasEnoughVelocityToSlideToTheNextCell || hasEnoughVelocityToSlideToThePreviousCell)
        
        if didUseSwipeToSkipCell {
            // Animate so that swipe is just continued
            let snapToIndex = indexOfCellBeforeDragging + (hasEnoughVelocityToSlideToTheNextCell ? 1 : -1)
            let toValue = pageWidth * CGFloat(snapToIndex)
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 1,
                initialSpringVelocity: velocity.x,
                options: .allowUserInteraction,
                animations: {
                    scrollView.contentOffset = CGPoint(x: toValue, y: 0)
                    scrollView.layoutIfNeeded()
            },
                completion: nil
            )
        } else {
            // Pop back (against velocity)
            let indexPath = IndexPath(row: indexOfMajorCell, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .left, animated: true)
        }
    }
}
