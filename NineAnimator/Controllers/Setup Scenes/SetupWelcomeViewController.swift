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

class SetupWelcomeViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // If on a large screen device, allow any screen orientations
        if traitCollection.horizontalSizeClass == .regular &&
            traitCollection.verticalSizeClass == .regular {
            return .all
        }
        
        // Else only allows portrait
        return .portrait
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        Theme.current.preferredStatusBarStyle
    }
    
    @IBOutlet private weak var appIconImageView: UIImageView!
    @IBOutlet private weak var welcomeTitleLabel: UILabel!
    @IBOutlet private weak var continueButton: ThemedSolidButton!
    @IBOutlet private weak var eulaLabel: UILabel!
    @IBOutlet private weak var skipSetupButton: UIButton!
    
    private var didShowAnimation = false
    private var scheduledDataMigrator = NineAnimator.default.user.availableModelMigrator()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hide the navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // If haven't shown animation yet, set alphas to zero
        if !didShowAnimation {
            appIconImageView.alpha = 0.0
            welcomeTitleLabel.alpha = 0.0
            continueButton.alpha = 0.0
            eulaLabel.alpha = 0.0
            skipSetupButton.alpha = 0.0
        }
        
        // If NineAnimator was updated from a previous version,
        // change the title to "Welcome Back"
        if NineAnimator.default.user.setupVersion != nil {
            welcomeTitleLabel.text = "Welcome Back"
            
            if scheduledDataMigrator != nil {
                welcomeTitleLabel.text = "Updating Data"
                continueButton.isEnabled = false
                skipSetupButton.isEnabled = false
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !didShowAnimation {
            didShowAnimation = true
            
            appIconImageView.animate(
                animations: [],
                initialAlpha: 0.0,
                finalAlpha: 1.0,
                duration: 0.7
            )
            welcomeTitleLabel.animate(
                animations: [
                    AnimationType.from(direction: .bottom, offset: 16)
                ],
                initialAlpha: 0.0,
                finalAlpha: 1.0,
                delay: 0.3,
                duration: 0.8
            )
            eulaLabel.animate(
                animations: [],
                initialAlpha: 0.0,
                finalAlpha: 1.0,
                delay: 1.0,
                duration: 0.5
            )
            continueButton.animate(
                animations: [],
                initialAlpha: 0.0,
                finalAlpha: 1.0,
                delay: 1.0,
                duration: 0.5
            )
            skipSetupButton.animate(
                animations: [],
                initialAlpha: 0.0,
                finalAlpha: 1.0,
                delay: 1.0,
                duration: 0.5
            )
        }
        
        // Perform migration
        if let modelVersion = NineAnimator.default.user.setupVersion, let migrator = scheduledDataMigrator {
            migrator.delegate = self
            migrator.beginMigration(sourceVersion: modelVersion)
        }
    }
    
    @IBAction private func onSkipSetupButtonTap(_ sender: Any) {
        if scheduledDataMigrator == nil {
            NineAnimator.default.user.markDidSetupLatestVersion()
            dismiss(animated: true)
        }
    }
    
    @IBAction private func onContinueButtonTap(_ sender: Any) {
        if scheduledDataMigrator == nil {
            performSegue(withIdentifier: "continue", sender: self)
        }
    }
}

extension SetupWelcomeViewController: ModelMigratorDelegate {
    func migrator(willBeginMigration migrator: ModelMigrator) {
        // Not doing anything atm
    }
    
    func migrator(migrationInProgress migrator: ModelMigrator, progress: ModelMigrationProgress) {
        // Not doing anything atm
    }
    
    func migrator(didCompleteMigration migrator: ModelMigrator, withError error: Error?) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3) {
                self.continueButton.isEnabled = true
                self.skipSetupButton.isEnabled = true
                self.welcomeTitleLabel.text = "Welcome Back"
                self.scheduledDataMigrator = nil
            }
        }
    }
}
