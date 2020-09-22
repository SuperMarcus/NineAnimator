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
import ViewAnimator

class SetupThemeViewController: UIViewController, Themable {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // If on a large screen device, allow any screen orientations
        if traitCollection.horizontalSizeClass == .regular &&
            traitCollection.verticalSizeClass == .regular {
            return .all
        }
        
        // Else only allows portrait
        return .portrait
    }
    
    @IBOutlet private weak var themeTitleLabel: UILabel!
    @IBOutlet private weak var appearanceSubtitleLabel: UILabel!
    @IBOutlet private weak var themeDescriptionLabel: UILabel!
    @IBOutlet private weak var continueButton: ThemedSolidButton!
    @IBOutlet private weak var themeSelectionSegmentedControl: UISegmentedControl!
    
    private var didShowAnimation = false
    
    func theme(didUpdate theme: Theme) {
        let themeName: String
        
        if NineAnimator.default.user.dynamicAppearance {
            if #available(iOS 13.0, *) {
                themeName = "System"
            } else { themeName = "Dynamic" }
            themeSelectionSegmentedControl.selectedSegmentIndex = 2
        } else if theme.name == "dark" {
            themeName = "Dark"
            themeSelectionSegmentedControl.selectedSegmentIndex = 1
        } else {
            themeName = "Light"
            themeSelectionSegmentedControl.selectedSegmentIndex = 0
        }
        
        themeTitleLabel.text = themeName
    }
    
    @IBAction private func onThemeDidSelect(_ sender: Any) {
        switch themeSelectionSegmentedControl.selectedSegmentIndex {
        case 0:
            if let theme = Theme.availableThemes["light"] {
                NineAnimator.default.user.dynamicAppearance = false
                Theme.setTheme(theme)
            }
        case 1:
            if let theme = Theme.availableThemes["dark"] {
                NineAnimator.default.user.dynamicAppearance = false
                Theme.setTheme(theme)
            }
        case 2:
            NineAnimator.default.user.dynamicAppearance = true
            
            if #available(iOS 13.0, *) {
                RootViewController.shared?.updateDynamicTheme()
            } else {
                AppDelegate.shared?.updateDynamicBrightness(forceUpdate: true)
            }
        default: break
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Listen to theme change event and react accordingly
        Theme.provision(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !didShowAnimation {
            themeTitleLabel.alpha = 0
            appearanceSubtitleLabel.alpha = 0
            continueButton.alpha = 0
            themeDescriptionLabel.alpha = 0
            themeSelectionSegmentedControl.alpha = 0
        }
        
        if #available(iOS 13.0, *) {
            themeDescriptionLabel.text = """
Select Light or Dark to use an appearance independent from the system.
After setup, you can change the theme settings in the Settings menu.
"""
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !didShowAnimation {
            didShowAnimation = true
            
            appearanceSubtitleLabel.animate(
                animations: [
                    AnimationType.from(direction: .bottom, offset: 16)
                ],
                initialAlpha: 0.0,
                finalAlpha: 1.0,
                delay: 0,
                duration: 0.5
            )
            themeTitleLabel.animate(
                animations: [
                    AnimationType.from(direction: .top, offset: 24)
                ],
                initialAlpha: 0.0,
                finalAlpha: 1.0,
                delay: 0,
                duration: 0.5
            )
            UIView.animate(
                views: [ themeSelectionSegmentedControl, themeDescriptionLabel, continueButton ],
                animations: [],
                initialAlpha: 0.0,
                finalAlpha: 1.0,
                delay: 0,
                duration: 0.5
            )
        }
    }
}
