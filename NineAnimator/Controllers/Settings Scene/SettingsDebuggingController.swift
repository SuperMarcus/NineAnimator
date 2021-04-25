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
        self.configureForTransparentScrollEdge()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.makeThemable()
        self.updateUIComponents()
    }
}

// MARK: - Delegate
extension SettingsDebuggingController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            // Deselect row
            tableView.deselectSelectedRows(animated: true)
        }
        
        guard let cell = tableView.cellForRow(at: indexPath),
              let cellReuseIdentifier = cell.reuseIdentifier else {
            return
        }
        
        switch cellReuseIdentifier {
        case "analytics.exportLogs":
            onExportRuntimeLogsSelected(source: cell)
        default: break
        }
    }
}

private extension SettingsDebuggingController {
    func updateUIComponents(animated: Bool = false) {
        let profile = NineAnimator.default.user
        optOutAnalyticsSwitch.setOn(profile.optOutAnalytics, animated: animated)
        redactLogsSwitch.setOn(profile.crashReporterRedactLogs, animated: animated)
    }
    
    func onExportRuntimeLogsSelected(source: UIView) {
        let alertController = UIAlertController(
            title: "Export Runtime Logs",
            message: "Export NineAnimator runtime logs for debugging. You may choose to export a redacted version for sharing with the developers. Redacted runtime logs remove all dynamic information such as anime title, episode name, playback progresses, etc.",
            preferredStyle: .actionSheet
        )
        
        alertController.addAction(UIAlertAction(title: "Redacted Version", style: .default) {
            [weak self, weak source] _ in DispatchQueue.main.async {
                if let self = self, let source = source {
                    self.performLogExportOperation(source: source, exportOptions: [ .redactParameters ])
                }
            }
        })
        
        alertController.addAction(UIAlertAction(title: "Full Version", style: .default) {
            [weak self, weak source] _ in DispatchQueue.main.async {
                if let self = self, let source = source {
                    self.performLogExportOperation(source: source, exportOptions: [])
                }
            }
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = source
            popoverController.sourceRect = source.bounds
        }
        
        self.present(alertController, animated: true)
    }
    
    private func performLogExportOperation(source: UIView, exportOptions: NineAnimatorLogger.ExportPrivacyOption) {
        do {
            let exportedFileURL = try Log.exportRuntimeLogs(privacyOptions: exportOptions)
            RootViewController.shared?.presentShareSheet(
                forURL: exportedFileURL,
                from: source,
                inViewController: self
            )
        } catch {
            let alertController = UIAlertController(error: error)
            self.present(alertController, animated: true)
        }
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
