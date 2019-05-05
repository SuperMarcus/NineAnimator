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

class DiscoveryStandardTableViewCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var viewMoreButton: UIButton!
    
    private let scrollBarHeightInset: CGFloat = 20
    private let standardCellWidth: CGFloat = 110
    
    private var recommendation: Recommendation?
    private var viewMoreContentProvider: ContentProvider?
    private weak var delegate: DiscoverySceneViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        collectionView.delegate = self
        collectionView.dataSource = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    @IBAction private func onViewMoreButtonTapped(_ sender: Any) {
        guard let recommendation = self.recommendation,
            let contentProvider = self.viewMoreContentProvider else { return }
        delegate?.onViewMoreButtonTapped(recommendation, contentProvider: contentProvider, from: self)
    }
}

extension DiscoveryStandardTableViewCell {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let recommendation = recommendation, section == 0 else { return 0 }
        return recommendation.items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let recommendation = recommendation, indexPath.section == 0 else { return UICollectionViewCell() }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "standard", for: indexPath) as! Cell
        cell.setPresenting(recommendation.items[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellParentBounds = collectionView.bounds
        let inset = collectionView.adjustedContentInset
        let height = cellParentBounds.height - inset.top - inset.bottom - scrollBarHeightInset
        
        return CGSize(width: standardCellWidth, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? Cell,
            let item = cell.recommendingItem {
            delegate?.didSelect(recommendingItem: item)
        }
    }
}

extension DiscoveryStandardTableViewCell {
    func setPresenting(_ recommendation: Recommendation, withDelegate delegate: DiscoverySceneViewController) {
        self.recommendation = recommendation
        self.delegate = delegate
        self.titleLabel.text = recommendation.title
        self.subtitleLabel.text = recommendation.subtitle
        collectionView.reloadData()
        
        self.viewMoreContentProvider = recommendation.completeItemListProvider()
        self.viewMoreButton.isHidden = self.viewMoreContentProvider == nil
    }
}
