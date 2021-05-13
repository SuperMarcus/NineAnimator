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

class AnimeScheduleCollectionViewController: MinFilledCollectionViewController, ContentProviderDelegate, DontBotherViewController, Themable {
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
        
        // Initialize Min Filled Layout
        setLayoutParameters(
            alwaysFillLine: false,
            minimalSize: .init(width: 300, height: 100)
        )
        
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
        loadedScheduledDays.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        loadedScheduledDays[section].collection.count
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
}

// MARK: - Data loading
extension AnimeScheduleCollectionViewController {
    func loadCalendarItems(on page: Int) {
        guard let source = calendarSource, source.availablePages > page else {
            return Log.error("[Weekly Schedule] Trying to load page %@ of the schedule while it doesn't exist", page)
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
            IndexPath(item: item, section: section)
        }
    }
}
