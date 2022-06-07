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
    
    // Whether to dismiss the setup scene automatically after the availability data becomes available
    fileprivate static var dismissConfigurationAfterAvailabilityDataRetrival: Bool {
        true
    }
    
    @IBOutlet private weak var appIconImageView: UIImageView!
    @IBOutlet private weak var welcomeTitleLabel: UILabel!
    @IBOutlet private weak var continueButton: ThemedSolidButton!
    @IBOutlet private weak var eulaLabel: UILabel!
    @IBOutlet private weak var skipSetupButton: UIButton!
    @IBOutlet private weak var setupLicenseLabel: UILabel!
    
    private var didShowAnimation = false
    private var scheduledDataMigrators: [ModelMigrator]?
    private var requiredConfigurations = false
    private var availabilityDataFetchingTask: NineAnimatorAsyncTask?
    private var licenseText: String?
    
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
            licenseText = setupLicenseLabel.text
        }
        
        // If NineAnimator was updated from a previous version,
        // change the title to "Welcome Back"
        if NineAnimator.default.user.setupVersion != nil {
            if let availableMigrators = NineAnimator.default.user.availableModelMigrators(),
               !availableMigrators.isEmpty {
                welcomeTitleLabel.text = "Updating Data"
                continueButton.isEnabled = false
                skipSetupButton.isEnabled = false
                requiredConfigurations = true
                scheduledDataMigrators = availableMigrators
            }
        }
    }
    
    func ensureAvailabilityData() {
        if !NineAnimator.default.cloud.isAvailabilityDataCached(),
           case .none = availabilityDataFetchingTask {
            UIView.animate(withDuration: 0.3) {
                self.continueButton.isEnabled = false
                self.skipSetupButton.isEnabled = false
                self.welcomeTitleLabel.text = "Checking Sources"
            }
            
            availabilityDataFetchingTask = NineAnimator.default.cloud
                .retrieveAvailabilityData()
                .dispatch(on: .main)
                .defer {
                    [weak self] _ in self?.availabilityDataFetchingTask = nil
                }
                .error {
                    [weak self] error in
                    guard let self = self else {
                        return
                    }
                    
                    // Indicates that there is an error
                    UIView.animate(withDuration: 0.3) {
                        self.continueButton.isEnabled = true
                        self.skipSetupButton.isEnabled = false
                        self.welcomeTitleLabel.text = "NineAnimator Unavailable"
                        self.setupLicenseLabel.text = "NineAnimator is unable to continue because we failed to retrieve a critical piece of data that is required for the app to function: \(error.localizedDescription)"
                        self.continueButton.setTitle("Retry", for: .normal)
                        self.requiredConfigurations = true // Window won't dismiss automatically after this
                    }
                }
                .finally {
                    [weak self] _ in
                    guard let self = self else {
                        return
                    }
                    
                    // Dismiss automatically if there was no user interaction
                    if !self.requiredConfigurations && Self.dismissConfigurationAfterAvailabilityDataRetrival {
                        return self.dismiss(animated: true)
                    }
                    
                    // Restore button states
                    UIView.animate(withDuration: 0.3) {
                        self.continueButton.isEnabled = true
                        self.skipSetupButton.isEnabled = true
                        self.welcomeTitleLabel.text = "Welcome to NineAnimator"
                        self.setupLicenseLabel.text = self.licenseText
                        self.continueButton.setTitle("Continue", for: .normal)
                    }
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
//                    AnimationType.from(direction: .bottom, offset: 16)
                    AnimationType.vector(.init(dx: 0, dy: 16))
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
        
        // Perform migrations
        if let modelVersion = NineAnimator.default.user.setupVersion,
           let migrator = scheduledDataMigrators?.first {
            migrator.delegate = self
            migrator.beginMigration(sourceVersion: modelVersion)
        } else if !NineAnimator.default.cloud.isAvailabilityDataCached() {
            ensureAvailabilityData()
        }
    }
    
    @IBAction private func onSkipSetupButtonTap(_ sender: Any) {
        if scheduledDataMigrators == nil || scheduledDataMigrators?.isEmpty == true,
           NineAnimator.default.cloud.isAvailabilityDataCached() {
            NineAnimator.default.user.markDidSetupLatestVersion()
            dismiss(animated: true)
        }
    }
    
    @IBAction private func onContinueButtonTap(_ sender: Any) {
        if !NineAnimator.default.cloud.isAvailabilityDataCached() {
            return ensureAvailabilityData()
        }
        
        if scheduledDataMigrators == nil || scheduledDataMigrators?.isEmpty == true {
            return performSegue(withIdentifier: "continue", sender: self)
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
        // Remove the completed migrator, and start the next migrator if available
        scheduledDataMigrators?.removeFirst()
        if let modelVersion = NineAnimator.default.user.setupVersion,
           let nextMigrator = scheduledDataMigrators?.first {
            nextMigrator.delegate = self
            nextMigrator.beginMigration(sourceVersion: modelVersion)
        } else {
            DispatchQueue.main.async {
                if NineAnimator.default.cloud.isAvailabilityDataCached() {
                    UIView.animate(withDuration: 0.3) {
                        self.continueButton.isEnabled = true
                        self.skipSetupButton.isEnabled = true
                        self.welcomeTitleLabel.text = "Welcome Back"
                        self.scheduledDataMigrators = nil
                    }
                } else {
                    self.ensureAvailabilityData()
                }
            }
        }
    }
}
