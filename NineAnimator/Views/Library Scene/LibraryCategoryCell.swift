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

class LibraryCategoryCell: UICollectionViewCell, Themable {
    // swiftlint:disable implicitly_unwrapped_optional
    private(set) unowned var category: LibrarySceneController.Category!
    
    @IBOutlet private weak var categoryIcon: UIImageView!
    @IBOutlet private weak var categoryNameLabel: UILabel!
    @IBOutlet private weak var categoryMarkerLabel: UILabel!
    
    private lazy var backgroundLayer = CAShapeLayer()
    
    func setPresenting(_ category: LibrarySceneController.Category) {
        self.category = category
        self.updateLabels()
        self.pointerEffect.hover()
    }
    
    func updateLabels() {
        categoryNameLabel.text = category.name
        categoryMarkerLabel.text = category.marker
        categoryIcon.image = category.icon
        
        // Update themes
        categoryNameLabel.makeThemable()
        categoryMarkerLabel.makeThemable()
    }
    
    func theme(didUpdate theme: Theme) {
        updateTouchReactionTint()
    }
    
    override var isHighlighted: Bool {
        didSet { updateTouchReactionTint() }
    }
    
    override var isSelected: Bool {
        didSet { updateTouchReactionTint() }
    }
    
    private func updateTouchReactionTint() {
        let shouldTint = isHighlighted || isSelected
        backgroundColor = shouldTint
            ? category.tintColor.withAlphaComponent(0.6) : Theme.current.background
    }
}
