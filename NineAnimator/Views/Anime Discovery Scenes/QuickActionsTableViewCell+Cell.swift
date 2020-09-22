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

extension QuickActionsTableViewCell {
    typealias Cell = QuickActionCollectionViewCell
}

class QuickActionCollectionViewCell: UICollectionViewCell {
    @IBOutlet private weak var actionButton: ThemedSolidButton!
    private var action: DiscoverySceneViewController.QuickAction?
    private var completionHandler: (() -> Void)?
    
    func setPresenting(_ action: DiscoverySceneViewController.QuickAction, completionHandler: @escaping (DiscoverySceneViewController.QuickAction) -> Void) {
        self.action = action
        self.completionHandler = { completionHandler(action) }
        actionButton.setTitle(action.title, for: .normal)
        actionButton.setImage(action.icon, for: .normal)
        pointerEffect.hover()
    }
    
    @IBAction private func onAction(_ sender: Any) {
        if let action = self.action, let completionHandler = self.completionHandler {
            action.onAction(completionHandler)
        }
    }
}
