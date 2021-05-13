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
import ViewAnimator

class SetupServerSelectionViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // If on a large screen device, allow any screen orientations
        if traitCollection.horizontalSizeClass == .regular &&
            traitCollection.verticalSizeClass == .regular {
            return .all
        }
        
        // Else only allows portrait
        return .portrait
    }
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var selectionView: ServerSelectionView!
    @IBOutlet private weak var informationLabel: UILabel!
    @IBOutlet private weak var continueButton: UIButton!
    
    private var didShowAnimations = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        selectionView.makeThemable()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !didShowAnimations {
            titleLabel.alpha = 0
            subtitleLabel.alpha = 0
            selectionView.alpha = 0
            informationLabel.alpha = 0
            continueButton.alpha = 0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !didShowAnimations {
            didShowAnimations = true
            UIView.animate(
                views: [ titleLabel ],
                animations: [
//                    AnimationType.from(direction: .top, offset: 16)
                    AnimationType.vector(.init(dx: 0, dy: -16))
                ],
                initialAlpha: 0,
                finalAlpha: 1,
                delay: 0,
                animationInterval: 0,
                duration: 0.5
            )
            UIView.animate(
                views: [ subtitleLabel ],
                animations: [
//                    AnimationType.from(direction: .bottom, offset: 16)
                    AnimationType.vector(.init(dx: 0, dy: 16))
                ],
                initialAlpha: 0,
                finalAlpha: 1,
                delay: 0,
                animationInterval: 0,
                duration: 0.5
            )
            UIView.animate(
                views: [ selectionView ],
                animations: [],
                initialAlpha: 0,
                finalAlpha: 1,
                delay: 0,
                animationInterval: 0,
                duration: 0.4
            )
            UIView.animate(
                views: selectionView.visibleCells,
                animations: [
//                    AnimationType.from(direction: .bottom, offset: 32)
                    AnimationType.vector(.init(dx: 0, dy: 32))
                ],
                initialAlpha: 0,
                finalAlpha: 1,
                delay: 0,
                animationInterval: 0,
                duration: 0.6
            )
            UIView.animate(
                views: [ informationLabel, continueButton ],
                animations: [],
                initialAlpha: 0,
                finalAlpha: 1,
                delay: 0,
                animationInterval: 0,
                duration: 0.5
            )
        }
    }
}
