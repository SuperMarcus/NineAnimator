//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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

import AuthenticationServices
import SafariServices
import UIKit

class TrackingServiceTableViewController: UITableViewController {
    // AniList
    @IBOutlet private weak var anilistStatusLabel: UILabel!
    @IBOutlet private weak var anilistActionLabel: UILabel!
    @IBOutlet private weak var anilistPushNineAnimatorUpdatesSwitch: UISwitch!
    private var anilistAccountInfoFetchTask: NineAnimatorAsyncTask?
    
    // Preserve a reference to the authentication session
    private var authenticationSessionReference: AnyObject?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update status
        anilistUpdateStatus()
        tableView.makeThemable()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectSelectedRow() }
        
        // Retrieve reuse identifier
        guard let cell = tableView.cellForRow(at: indexPath),
            let identifier = cell.reuseIdentifier else {
            return
        }
        
        switch identifier {
        case "service.anilist.action":
            if anilist.didExpire || !anilist.didSetup {
                anilistPresentAuthenticationPage()
            } else { anilistLogOut() }
        default:
            Log.info("An unimplemented cell with identifier \"%@\" was selected", identifier)
        }
    }
}

// MARK: - AniList.co specifics
extension TrackingServiceTableViewController {
    private var anilist: Anilist { return NineAnimator.default.service(type: Anilist.self) }
    
    private func anilistUpdateStatus() {
        // Disable switch by default
        anilistPushNineAnimatorUpdatesSwitch.setOn(false, animated: true)
        anilistPushNineAnimatorUpdatesSwitch.isEnabled = false
        
        if anilist.didSetup {
            if anilist.didExpire {
                anilistStatusLabel.text = "Expired"
                anilistActionLabel.text = "Authenticate AniList.co"
            } else {
                anilistStatusLabel.text = "Loading..."
                anilistActionLabel.text = "Log Out"
                
                let updateStatusLabel = {
                    text in
                    DispatchQueue.main.async { [weak self] in self?.anilistStatusLabel.text = text }
                }
                
                anilistAccountInfoFetchTask = anilist.currentUser()
                    .error { _ in updateStatusLabel("Error") }
                    .finally { updateStatusLabel("Signed in as \($0.name)") }
                
                // Update the state accordingly
                anilistPushNineAnimatorUpdatesSwitch.setOn(anilist.isTrackingEnabled, animated: true)
                anilistPushNineAnimatorUpdatesSwitch.isEnabled = true
            }
        } else { // Present initial setup labels
            anilistStatusLabel.text = "Not Setup"
            anilistActionLabel.text = "Setup AniList.co"
        }
    }
    
    @IBAction private func anilistOnPushNineAnimatorUpdatesToggled(_ sender: UISwitch) {
        anilist.isTrackingEnabled = sender.isOn
    }
    
    // Present the SSO login page
    private func anilistPresentAuthenticationPage() {
        let callback: NineAnimatorCallback<URL> = {
            [weak anilist, weak self] url, callbackError in
            defer { DispatchQueue.main.async { [weak self] in self?.anilistUpdateStatus() } }
            var error = callbackError
            
            // If callback url is provided
            if let url = url {
                error = anilist?.authenticate(with: url)
            }
            
            // If an error is present
            if let error = error {
                Log.error("[AniList.co] Authentication session finished with error: %@", error)
            }
        }
        
        // Open the authentication dialog/web page
        if #available(iOS 12.0, *) {
            let session = ASWebAuthenticationSession(url: anilist.ssoUrl, callbackURLScheme: anilist.ssoCallbackScheme, completionHandler: callback)
            _ = session.start()
            authenticationSessionReference = session
        } else {
            let session = SFAuthenticationSession(url: anilist.ssoUrl, callbackURLScheme: anilist.ssoCallbackScheme, completionHandler: callback)
            _ = session.start()
            authenticationSessionReference = session
        }
    }
    
    // Tell AniList service to logout
    private func anilistLogOut() {
        anilist.deauthenticate()
        anilistUpdateStatus()
    }
}
