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

import UIKit

class LibraryCollectionCell: UICollectionViewCell, Themable {
    @IBOutlet private weak var collectionIconView: UIImageView!
    @IBOutlet private weak var collectionLabel: UILabel!
    @IBOutlet private weak var seperatorLine: UIView!
    @IBOutlet private weak var detailAccessoryImageView: UIImageView!
    
    private(set) var collection: LibrarySceneController.Collection?
    private let defaultCornerRadius: CGFloat = 10
    
    func setPresenting(_ collection: LibrarySceneController.Collection) {
        self.collection = collection
        self.collectionLabel.text = collection.title
        self.collectionIconView.image = #imageLiteral(resourceName: "List Icon HD")
        self.pointerEffect.hover(shadow: true)
    }
    
    func theme(didUpdate theme: Theme) {
        backgroundColor = theme.background
        seperatorLine.backgroundColor = theme.seperator
        detailAccessoryImageView.tintColor = theme.secondaryText
    }
    
    func updateApperance(baseOff layoutParameters: MinFilledFlowLayoutHelper.LayoutParameters) {
        var maskedCorners = CACornerMask()
        
        // First Row
        if layoutParameters.line == 0 {
            if layoutParameters.item == 0 {
                maskedCorners.insert(.layerMinXMinYCorner)
            }
            
            if layoutParameters.item == (layoutParameters.itemsInLine - 1) {
                maskedCorners.insert(.layerMaxXMinYCorner)
            }
        }
        
        // Last Row
        if layoutParameters.line == (layoutParameters.numberOfLines - 1) {
            if layoutParameters.item == 0 {
                maskedCorners.insert(.layerMinXMaxYCorner)
            }
            
            if layoutParameters.item == (layoutParameters.itemsInLine - 1) {
                maskedCorners.insert(.layerMaxXMaxYCorner)
            }
            
            seperatorLine.alpha = 0
        } else { seperatorLine.alpha = 1 }
        
        layer.maskedCorners = maskedCorners
        layer.cornerRadius = defaultCornerRadius
    }
    
    override var isHighlighted: Bool {
        didSet { updateTouchReactionTint() }
    }
    
    override var isSelected: Bool {
        didSet { updateTouchReactionTint() }
    }
    
    private func updateTouchReactionTint() {
        let shouldTint = isHighlighted || isSelected
        alpha = shouldTint ? 0.4 : 1
    }
}
