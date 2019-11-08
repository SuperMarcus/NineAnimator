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

import Kingfisher
import UIKit

class LibraryTipSubscriptionAvailableCell: UICollectionViewCell {
    @IBOutlet private weak var descriptionLabel: UILabel!
    
    private(set) var presentingLinks: [AnimeLink]?
    
    func setPresenting(_ updatedAnimeLinks: [AnimeLink]) {
        self.presentingLinks = updatedAnimeLinks
        let updatedCount = updatedAnimeLinks.count
        if updatedCount == 1,
            let updatedAnime = updatedAnimeLinks.first {
            descriptionLabel.text = "A new episode of \(updatedAnime.title) is now available. Stream now from \(updatedAnime.source.name)."
        } else {
            descriptionLabel.text = "\(updatedAnimeLinks.count) anime you've subscribed have new episodes available and \(updatedCount > 1 ? "are" : "is") now available for streaming."
        }
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
