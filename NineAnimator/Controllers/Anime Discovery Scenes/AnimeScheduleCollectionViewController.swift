//
//  AnimeScheduleCollectionViewController.swift
//  NineAnimator
//
//  Created by Xule Zhou on 5/4/19.
//  Copyright © 2019 Marcus Zhou. All rights reserved.
//

import UIKit

class AnimeScheduleCollectionViewController: UICollectionViewController, ContentProviderDelegate, DontBotherViewController, Themable {
    // Defining constants
    
    /// The maximal cell width before increasing the number of cells in a line
    private let maximalCellWidth: CGFloat = 450
    private let cellHeight: CGFloat = 100
    
    // Stored properties
    
    private var previousBounds: CGSize = .zero
    private(set) var calendarSource: CalendarProvider?
    private var loadedScheduledDays = [ScheduledDay]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Inset from the sides
        collectionView.contentInset = .init(top: 0, left: 8, bottom: 0, right: 8)
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?
            .sectionHeadersPinToVisibleBounds = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let source = calendarSource {
            self.calendarSource?.delegate = self
            
            // Load any unloaded pages
            if loadedScheduledDays.count < source.availablePages {
                for page in (loadedScheduledDays.count..<source.availablePages) {
                    loadCalendarItems(on: page)
                }
            } else if loadedScheduledDays.isEmpty {
                self.calendarSource?.more()
            }
        } else {
            // Remove all items
            collectionView.contentOffset = .zero
            loadedScheduledDays = []
            collectionView.reloadData()
        }
        
        // Add theming effect
        Theme.provision(self)
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let height = scrollView.frame.size.height
        let contentYoffset = scrollView.contentOffset.y
        let distanceFromBottom = scrollView.contentSize.height - contentYoffset
        if distanceFromBottom < (2.5 * height) { calendarSource?.more() }
    }
    
    func theme(didUpdate theme: Theme) {
        // This is just to make the navigation bar a bit more opaque and harder to
        // distinquish the differences between section headers and the bar
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        
        // Animate navigation bar style and color
        UIView.animate(withDuration: 0.2) {
            [weak navigationController] in
            navigationController?.navigationBar.barTintColor = theme.translucentBackground
            navigationController?.navigationBar.backgroundColor = theme.background
            navigationController?.navigationBar.tintColor = theme.tint
            navigationController?.navigationBar.layoutIfNeeded()
        }
    }
    
    func pageIncoming(_ page: Int, from provider: ContentProvider) {
        DispatchQueue.main.async {
            self.loadCalendarItems(on: page)
        }
    }
    
    func onError(_ error: Error, from provider: ContentProvider) {
        Log.error(error)
    }
    
    // MARK: - Data source

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return loadedScheduledDays.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return loadedScheduledDays[section].collection.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "schedule.cell", for: indexPath) as! CalendarAnimeCell
        cell.setPresenting(loadedScheduledDays[indexPath.section].collection[indexPath.item], withDelegate: self)
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            Log.error("[Weekly Schedule] Trying to create a non-supported supplementary view of kind %@", kind)
            return UICollectionReusableView()
        }
        
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "schedule.header", for: indexPath) as! CalendarHeaderView
        view.setPresenting(loadedScheduledDays[indexPath.section], withDelegate: self)
        return view
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let view = collectionView.cellForItem(at: indexPath) as? CalendarAnimeCell,
            let item = view.representingScheduledAnime {
            RootViewController.shared?.open(immedietly: item.link, in: self)
        }
    }
    
    override func viewWillLayoutSubviews() {
        if view.bounds.width != previousBounds.width,
            let cvLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            // Calculate the cell width based on the new width of the collection view
            let interLineSpacing = cvLayout.minimumInteritemSpacing
            let availableWidth = view.bounds.inset(by: collectionView.adjustedContentInset).width
            
            let numberOfItemsPerLine = ceil((availableWidth + interLineSpacing) / (maximalCellWidth + interLineSpacing))
            let cellWidth = (availableWidth + interLineSpacing) / numberOfItemsPerLine - interLineSpacing
            
            // Store the calculated size
            cvLayout.itemSize = CGSize(width: cellWidth, height: cellHeight)
            
            // Last, invalidate the collection view layout
            cvLayout.invalidateLayout()
        }
        previousBounds = view.bounds.size
        
        super.viewWillLayoutSubviews()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: {
            _ in self.collectionView.performBatchUpdates({
                self.collectionView.layoutIfNeeded()
            }, completion: nil)
        }, completion: nil)
    }
}

// MARK: - Data loading
extension AnimeScheduleCollectionViewController {
    func loadCalendarItems(on page: Int) {
        guard let source = calendarSource, source.availablePages > page else {
            return Log.error("[Weekly Schedule] Trying to load page %@ of the schedule while it doesn't exists", page)
        }
        
        collectionView.performBatchUpdates({
            // Keep track of changed items
            var insertedItems = [IndexPath]()
            
            // Iterate through the links
            for (sourceContainerOffset, link) in source.links(on: page).enumerated() {
                let broadcastDate = source.date(for: link, on: page)
                let container = getScheduledDay(for: broadcastDate)
                
                // Create the scheduled anime object
                var scheduledAnimeItem = ScheduledAnime(
                    link: link,
                    broadcastDate: broadcastDate,
                    presentationTitle: link.name,
                    presentationSubtitle: ""
                )
                
                // Add additional attributes
                if let source = source as? AttributedContentProvider & CalendarProvider,
                    let attributes = source.attributes(for: link, index: sourceContainerOffset, on: page) {
                    // Set title
                    attributes.title.unwrap {
                        scheduledAnimeItem.presentationTitle = $0
                    }
                    
                    // Set subtitle
                    attributes.subtitle.unwrap {
                        scheduledAnimeItem.presentationSubtitle = $0
                    }
                }
                
                // Enqueue the index path and item
                let appendingItemIndex = container.collection.count
                container.collection.append(scheduledAnimeItem)
                insertedItems.append(container[appendingItemIndex])
            }
            
            // Notify the collection view for changes
            collectionView.insertItems(at: insertedItems)
        }, completion: nil)
    }
    
    func getScheduledDay(for date: Date) -> ScheduledDay {
        let referenceDate = Calendar.current.startOfDay(for: date)
        
        // Return the existing container if exists
        if let matchedDayContainer = loadedScheduledDays.first(where: { $0.referenceDate == referenceDate }) {
            return matchedDayContainer
        } else {
            // Create new container and notify collection view
            let newContainerSectionIndex = loadedScheduledDays.count
            let newContainer = ScheduledDay(withReferenceDate: referenceDate, onSection: newContainerSectionIndex)
            // This assumes that the data are inputed in orders
            loadedScheduledDays.append(newContainer)
            collectionView.insertSections([ newContainerSectionIndex ])
            return newContainer
        }
    }
}

// MARK: - Initialization
extension AnimeScheduleCollectionViewController {
    func setPresenting(_ source: CalendarProvider) {
        self.calendarSource = source
    }
}

// MARK: - Types
extension AnimeScheduleCollectionViewController {
    struct ScheduledAnime: Hashable {
        var link: AnyLink
        var broadcastDate: Date
        var presentationTitle: String
        var presentationSubtitle: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(link)
        }
    }
    
    class ScheduledDay {
        var referenceDate: Date
        var collection: [ScheduledAnime] = []
        var section: Int
        
        init(withReferenceDate date: Date, onSection section: Int) {
            self.referenceDate = date
            self.collection = []
            self.section = section
        }
        
        subscript(_ item: Int) -> IndexPath {
            return IndexPath(item: item, section: section)
        }
    }
}
