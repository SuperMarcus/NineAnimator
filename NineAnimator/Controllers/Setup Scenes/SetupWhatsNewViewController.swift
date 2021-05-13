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

class SetupWhatsNewViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // If on a large screen device, allow any screen orientations
        if traitCollection.horizontalSizeClass == .regular &&
            traitCollection.verticalSizeClass == .regular {
            return .all
        }
        
        // Else only allows portrait
        return .portrait
    }
    
    @IBOutlet private weak var whatsNewTitleLabel: UILabel!
    @IBOutlet private var newFeaturesView: [UIView]!
    @IBOutlet private weak var versionInformationLabel: UILabel!
    @IBOutlet private weak var continueButton: UIButton!
    
    private var didShowAnimations = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set version string
        let originalText = versionInformationLabel.text ?? ""
        let versionTextString = "(NineAnimator Version \(NineAnimator.default.version) Build \(NineAnimator.default.buildNumber))"
        versionInformationLabel.text = [ originalText, versionTextString ].joined(separator: " ")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !didShowAnimations {
            whatsNewTitleLabel.alpha = 0.0
            newFeaturesView.forEach { $0.alpha = 0.0 }
            versionInformationLabel.alpha = 0.0
            continueButton.alpha = 0.0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Unhide the navigation bar
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        if !didShowAnimations {
            didShowAnimations = true
            
            whatsNewTitleLabel.animate(
                animations: [],
                initialAlpha: 0.0,
                finalAlpha: 1.0,
                delay: 0.2,
                duration: 0.7
            )
            UIView.animate(
                views: newFeaturesView,
                animations: [
//                    AnimationType.from(direction: .right, offset: 32)
                    AnimationType.vector(.init(dx: 32, dy: 0))
                ],
                delay: 0.4,
                animationInterval: 0.4,
                duration: 0.6
            ) {
                [versionInformationLabel, continueButton] in
                guard let view1 = versionInformationLabel, let view2 = continueButton else { return }
                UIView.animate(
                    views: [ view1, view2 ],
                    animations: [],
                    delay: 0,
                    duration: 0.4
                )
            }
        }
    }
}
