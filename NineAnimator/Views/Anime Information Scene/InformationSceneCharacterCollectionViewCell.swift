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

// swiftlint:disable type_name
class InformationSceneCharacterCollectionViewCell: UICollectionViewCell {
    @IBOutlet private weak var avatarImageView: UIImageView!
    @IBOutlet private weak var characterNameLabel: UILabel!
    @IBOutlet private weak var voiceActorNameLabel: UILabel!
    
    func initialize(_ character: ListingAnimeCharacter) {
        // Animate avatar
        avatarImageView.alpha = 0.0
        avatarImageView.kf.setImage(with: character.image) {
            [avatarImageView] _ in UIView.animate(withDuration: 0.2) {
                avatarImageView?.alpha = 1.0
            }
        }
        
        // Set name
        characterNameLabel.text = character.name
        voiceActorNameLabel.text = character.voiceActorName
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return systemLayoutSizeFitting(size)
    }
}
// swiftlint:enable type_name
