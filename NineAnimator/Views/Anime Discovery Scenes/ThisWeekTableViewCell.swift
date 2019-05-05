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

class ThisWeekTableViewCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var viewFullScheduleButton: UIButton!
    
    private var recommendation: Recommendation?
    private weak var delegate: DiscoverySceneViewController?
    private var fullScheduleCalendarProvider: CalendarProvider?
    
    private let maxItemWidth: CGFloat = 420
    private let scrollBarHeightInset: CGFloat = 20
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Set delegate and datasource
        collectionView.delegate = self
        collectionView.dataSource = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellParentBounds = collectionView.bounds
        let inset = collectionView.adjustedContentInset
        let height = cellParentBounds.height - inset.top - inset.bottom - scrollBarHeightInset
        let maxWidth = cellParentBounds.width - inset.left - inset.right
        
        return CGSize(width: min(maxWidth, maxItemWidth), height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard section == 0, let recommendation = recommendation else { return 0 }
        return recommendation.items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.section == 0, let recommendation = recommendation else {
            return UICollectionViewCell()
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "thisweek.cell", for: indexPath) as! Cell
        cell.setPresenting(recommendation.items[indexPath.item])
        return cell
    }
}

extension ThisWeekTableViewCell {
    func setPresenting(_ recommendation: Recommendation, withDelegate delegate: DiscoverySceneViewController) {
        self.recommendation = recommendation
        self.delegate = delegate
        
        self.fullScheduleCalendarProvider = recommendation.completeItemListProvider() as? CalendarProvider
        self.viewFullScheduleButton.isHidden = self.fullScheduleCalendarProvider == nil
        
        collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? Cell,
            let item = cell.recommendingItem {
            delegate?.didSelect(recommendingItem: item)
        }
    }
    
    @IBAction private func onViewScheduleButtonTapped(_ sender: Any) {
        if let recommendation = self.recommendation,
            let calendarProvider = self.fullScheduleCalendarProvider {
            delegate?.onViewMoreButtonTapped(recommendation, contentProvider: calendarProvider, from: self)
        }
    }
}
