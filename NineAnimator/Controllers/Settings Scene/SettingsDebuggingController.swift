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

import AppCenter
import AppCenterAnalytics
import AppCenterCrashes
import UIKit

class SettingsDebuggingController: UITableViewController {
    @IBOutlet private var optOutAnalyticsSwitch: UISwitch!
    @IBOutlet private var redactLogsSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

extension SettingsDebuggingController {
    private func updateUIComponents() {
        let profile = NineAnimator.default.user
        optOutAnalyticsSwitch.setOn(profile.optOutAnalytics, animated: true)
    }
}

// MARK: - IBActions
extension SettingsDebuggingController {
    @IBAction private func onOptOutAnalyticsSwitchDidToggle(_ sender: UISwitch) {
        NineAnimator.default.user.optOutAnalytics = sender.isOn
        Analytics.enabled = !sender.isOn
    }
    
    @IBAction private func onCrashReporterRedactedLogsDidToggle(_ sender: UISwitch) {
        NineAnimator.default.user.crashReporterRedactLogs = sender.isOn
    }
}
