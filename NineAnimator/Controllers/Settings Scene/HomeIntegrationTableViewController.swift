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

private enum DeferredSelectSceneEvent {
    case startScene
    case endScene
}

class HomeIntegrationTableViewController: UITableViewController {
    @IBOutlet private weak var externalPlaybackOnlySwitch: UISwitch!
    
    @IBOutlet private weak var startsPlayingActionSetLabel: UILabel!
    
    @IBOutlet private weak var endsPlayingActionSetLabel: UILabel!
    
    private var queuedSelectionEvent: DeferredSelectSceneEvent?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(homeDidUpdate(notification:)),
            name: .homeDidUpdate,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(homeDidReceiveAuthorizationStatus(notification:)),
            name: .homeDidReceiveAuthroizationStatus,
            object: nil
        )
        
        updatePreferences()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Update and sync preferences
extension HomeIntegrationTableViewController {
    fileprivate func updatePreferences() {
        if let startsSceneUUID = NineAnimator.default.user.homeIntegrationStartsActionSetUUID {
            startsPlayingActionSetLabel.text = HomeController.shared.name(forScene: startsSceneUUID) ?? "Unavailable"
        } else { startsPlayingActionSetLabel.text = "Not Setup" }
        
        if let endsSceneUUID = NineAnimator.default.user.homeIntegrationEndsActionSetUUID {
            endsPlayingActionSetLabel.text = HomeController.shared.name(forScene: endsSceneUUID) ?? "Unavailable"
        } else { endsPlayingActionSetLabel.text = "Not Setup" }
        
        externalPlaybackOnlySwitch.setOn(NineAnimator.default.user.homeIntegrationRunOnExternalPlaybackOnly, animated: true)
    }
    
    @IBAction private func onExternalPlaybackValueChange(_ sender: UISwitch) {
        NineAnimator.default.user.homeIntegrationRunOnExternalPlaybackOnly = sender.isOn
    }
}

// MARK: - Observers
extension HomeIntegrationTableViewController {
    @objc private func homeDidUpdate(notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.updatePreferences() }
        
        // Open deferred selection menu
        if let queuedEvent = queuedSelectionEvent {
            queuedSelectionEvent = nil
            _openSelectionMenu(for: queuedEvent)
        }
    }
    
    @objc private func homeDidReceiveAuthorizationStatus(notification: Notification) {
        if HomeController.shared.isPermissionDenied,
            self.queuedSelectionEvent != nil {
            self.queuedSelectionEvent = nil
            
            DispatchQueue.main.async {
                [weak self] in
                guard let self = self else { return }
                self.updatePreferences()
                self.showUnauthorizedAlert()
            }
        }
    }
}

// MARK: - Handling selections
extension HomeIntegrationTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let reuseIdentifier = tableView.cellForRow(at: indexPath)?.reuseIdentifier else {
            Log.error("Unable to retrieve cell reuse identifier")
            tableView.deselectSelectedRows()
            return
        }
        
        switch reuseIdentifier {
        case "home.scene.start": openSelectionMenu(for: .startScene)
        case "home.scene.end": openSelectionMenu(for: .endScene)
        default: tableView.deselectSelectedRows()
        }
    }
    
    private func openSelectionMenu(for event: DeferredSelectSceneEvent) {
        HomeController.shared.prime()
        
        if HomeController.shared.isPermissionDenied {
            showUnauthorizedAlert()
        } else if HomeController.shared.isReady == true {
            _openSelectionMenu(for: event)
        } else { queuedSelectionEvent = event }
    }
    
    private func _openSelectionMenu(for event: DeferredSelectSceneEvent) {
        let currentSceneUUID: UUID? = {
            switch event {
            case .startScene: return NineAnimator.default.user.homeIntegrationStartsActionSetUUID
            case .endScene: return NineAnimator.default.user.homeIntegrationEndsActionSetUUID
            }
        }()
        let availableScenes = HomeController.shared.availableScenes
        
        let alert = UIAlertController(title: "Scene to Run", message: nil, preferredStyle: .actionSheet)
        
        if let popoverController = alert.popoverPresentationController {
            switch event {
            case .startScene: popoverController.sourceView = startsPlayingActionSetLabel
            case .endScene: popoverController.sourceView = endsPlayingActionSetLabel
            }
        }
        
        func finishWithNewUUID(_ uuid: UUID?) {
            switch event {
            case .startScene:
                NineAnimator.default.user.homeIntegrationStartsActionSetUUID = uuid
            case .endScene:
                NineAnimator.default.user.homeIntegrationEndsActionSetUUID = uuid
            }
            DispatchQueue.main.async { [weak self] in
                if let indexPath = self?.tableView.indexPathForSelectedRow {
                    self?.tableView.deselectRow(at: indexPath, animated: true)
                }
                self?.updatePreferences()
            }
        }
        
        for scene in availableScenes {
            let action = UIAlertAction(title: scene.value, style: .default) {
                _ in finishWithNewUUID(scene.key)
            }
            action.setValue(scene.key == currentSceneUUID, forKey: "checked")
            alert.addAction(action)
        }
        
        let noSceneAction = UIAlertAction(title: "Do Nothing", style: .default) {
            _ in finishWithNewUUID(nil)
        }
        noSceneAction.setValue(currentSceneUUID == nil, forKey: "checked")
        alert.addAction(noSceneAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) {
            [weak self] _ in
            if let indexPath = self?.tableView.indexPathForSelectedRow {
                self?.tableView.deselectRow(at: indexPath, animated: true)
            }
        }
        alert.addAction(cancelAction)
        
        DispatchQueue.main.async {
            [weak self] in self?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func showUnauthorizedAlert() {
        let alert = UIAlertController(
            title: "Permission Denied",
            message: "NineAnimator does not have permission to access your HomeKit data. Please allow HomeKit access from your Settings app.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: "Ok",
            style: .cancel
        ) { [weak self] _ in self?.tableView.deselectSelectedRows() })
        
        present(alert, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.makeThemable()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.makeThemable()
        configureForTransparentScrollEdge()
    }
}
