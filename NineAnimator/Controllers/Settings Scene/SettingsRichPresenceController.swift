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

class SettingsRichPresenceController: UITableViewController {
    /// Current status of the rich presence service
    class var currentStatus: String {
        NineAnimator.presenceController.isAvailable ?
            NineAnimator.default.user.richPresenceEnabled ?
                NineAnimator.presenceController.isConnected ? "Connected" : "Available"
                : "Disabled"
            : "Unavailable"
    }
    
    @IBOutlet private weak var richPresenceEnabledSwitch: UISwitch!
    @IBOutlet private weak var richPresenceShowAnimeTitleSwitch: UISwitch!
    @IBOutlet private weak var richPresenceStatusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(_onRpcServiceConnectionStateDidUpdate(notification:)),
            name: .presenceControllerConnectionStateDidUpdate,
            object: nil
        )
        configureForTransparentScrollEdge()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.makeThemable()
        self._updateUIComponents()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectSelectedRows()
    }
    
    private func _updateUIComponents() {
        richPresenceEnabledSwitch.isEnabled =
            NineAnimator.presenceController.isAvailable
        richPresenceEnabledSwitch.setOn(
            NineAnimator.presenceController.isAvailable
                && NineAnimator.default.user.richPresenceEnabled,
            animated: true
        )
        richPresenceShowAnimeTitleSwitch.isEnabled =
            NineAnimator.presenceController.isAvailable
        richPresenceShowAnimeTitleSwitch.setOn(
            NineAnimator.presenceController.isAvailable
                && NineAnimator.default.user.richPresenceShowAnimeName,
            animated: true
        )
        _updateStatusText()
    }
    
    @IBAction private func _onEnableSwitchToggle(_ sender: UISwitch) {
        NineAnimator.default.user.richPresenceEnabled = sender.isOn
        _updateStatusText()
        NineAnimator.presenceController.reset()
    }
    
    @IBAction private func _onShowAnimeSwitchToggle(_ sender: UISwitch) {
        NineAnimator.default.user.richPresenceShowAnimeName = sender.isOn
    }
    
    @objc private func _onRpcServiceConnectionStateDidUpdate(notification: Notification) {
        DispatchQueue.main.async {
            [weak self] in self?._updateStatusText()
        }
    }
    
    private func _updateStatusText() {
        self.richPresenceStatusLabel?.text = SettingsRichPresenceController.currentStatus
    }
}
