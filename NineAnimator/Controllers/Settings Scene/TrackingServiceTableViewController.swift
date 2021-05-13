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

import AuthenticationServices
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources
import SafariServices
import UIKit

class TrackingServiceTableViewController: UITableViewController {
    // AniList
    @IBOutlet private weak var anilistStatusLabel: UILabel!
    @IBOutlet private weak var anilistActionLabel: UILabel!
    @IBOutlet private weak var anilistPushNineAnimatorUpdatesSwitch: UISwitch!
    private var anilistAccountInfoFetchTask: NineAnimatorAsyncTask?
    
    // Kitsu.io
    @IBOutlet private weak var kitsuStatusLabel: UILabel!
    @IBOutlet private weak var kitsuActionLabel: UILabel!
    @IBOutlet private weak var kitsuPushNineAnimatorUpdatesSwitch: UISwitch!
    private var kitsuAuthenticationTask: NineAnimatorAsyncTask?
    private var kitsuAccountInfoFetchTask: NineAnimatorAsyncTask?
    
    // MAL
    @IBOutlet private weak var malStatusLabel: UILabel!
    @IBOutlet private weak var malActionLabel: UILabel!
    private var malAuthenticationTask: NineAnimatorAsyncTask?
    private var malAccountInfoFetchTask: NineAnimatorAsyncTask?
    
    // Simkl
    @IBOutlet private weak var simklStatusLabel: UILabel!
    @IBOutlet private weak var simklActionLabel: UILabel!
    private var simklAccountInfoFetchTask: NineAnimatorAsyncTask?
    
    // Preserve a reference to the authentication session
    private var authenticationSessionReference: AnyObject?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update status
        anilistUpdateStatus()
        kitsuUpdateStatus()
        malUpdateStatus()
        simklUpdateStatus()
        
        tableView.makeThemable()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureForTransparentScrollEdge()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectSelectedRows() }
        
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
        case "service.kitsu.action":
            if !kitsu.didSetup {
                kitsuPresentAuthenticationPage()
            } else { kitsuLogout() }
        case "service.mal.action":
            if !mal.didSetup {
                malPresentAuthenticationPage()
            } else { malLogout() }
        case "service.simkl.action":
            if !simkl.didSetup {
                simklPresentAuthenticationPage()
            } else { simklLogOut() }
        default:
            Log.info("An unimplemented cell with identifier \"%@\" was selected", identifier)
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let cell = tableView.cellForRow(at: indexPath) else { return indexPath }
        
        // Disable the action cell if there is a task running
        
        if cell.reuseIdentifier == "service.kitsu.action",
            kitsuAuthenticationTask != nil {
            return nil
        }
        
        if cell.reuseIdentifier == "service.mal.action",
            malAuthenticationTask != nil {
            return nil
        }
        
        return indexPath
    }
}

// MARK: - MAL specifics
extension TrackingServiceTableViewController {
    private var mal: MyAnimeList { NineAnimator.default.service(type: MyAnimeList.self) }
    
    private func malPresentAuthenticationPage() {
        if #available(iOS 13.0, *) {
            self.malPresentSSOAuthenticationPage()
        } else { self.malPresentLegacyAuthenticationPage() }
    }
    
    @available(iOS, deprecated: 13.0, message: "Use of legacy MAL authentication schemes.")
    private func malPresentLegacyAuthenticationPage() {
        let alert = UIAlertController(
            title: "Setup MyAnimeList",
            message: "Login to MyAnimeList.net with your account name and password.",
            preferredStyle: .alert
        )
        
        // Username field
        alert.addTextField {
            $0.placeholder = "User Name"
            $0.textContentType = .username
        }
        
        // Password field
        alert.addTextField {
            $0.placeholder = "Password"
            $0.textContentType = .password
            $0.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "Sign In", style: .default) {
            [unowned mal, weak self, unowned alert] _ in
            guard let self = self else { return }
            
            // Obtain username and password values
            guard let user = alert.textFields?.first?.text,
                let password = alert.textFields?.last?.text else {
                    return
            }
            
            // Create authentication task
            self.malAuthenticationTask = mal
                .authenticate(withUser: user, password: password)
                .dispatch(on: .main)
                .error {
                    [weak self] error in
                    guard let self = self else { return }
                    
                    // Present the error message
                    let errorAlert = UIAlertController(
                        error: error,
                        customTitle: "Authentication Error",
                        allowRetry: false,
                        source: self,
                        completionHandler: nil
                    )
                    
                    self.malAuthenticationTask = nil
                    self.present(errorAlert, animated: true)
                    self.malUpdateStatus()
                } .finally {
                    [weak self] in
                    Log.info("[MyAnimeList.net] Successfully logged in to MyAnimeList.net")
                    self?.malAuthenticationTask = nil
                    self?.malUpdateStatus()
                }
            
            self.malUpdateStatus()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func malLogout() {
        mal.deauthenticate()
        malUpdateStatus()
    }
    
    private func malUpdateStatus() {
        // First, tint the action label
        malActionLabel.textColor = Theme.current.tint
        
        if mal.didSetup {
            malStatusLabel.text = "Updating"
            malActionLabel.text = "Sign Out"
            
            // Fetch current user info
            malAccountInfoFetchTask = mal
                .currentUser()
                .dispatch(on: .main)
                .error {
                    [weak malStatusLabel] _ in
                    malStatusLabel?.text = "Error"
                } .finally {
                    [weak malStatusLabel] user in
                    malStatusLabel?.text = "Signed in as \(user.name)"
                }
        } else if malAuthenticationTask != nil {
            malStatusLabel.text = "Updating"
            malActionLabel.text = "Signing you in..."
            malActionLabel.textColor = Theme.current.secondaryText
        } else {
            malStatusLabel.text = "Not Setup"
            malActionLabel.text = "Setup MyAnimeList.net"
        }
    }
    
    // Present the SSO login page
    @available(iOS 13.0, *)
    private func malPresentSSOAuthenticationPage() {
        let callback: NineAnimatorCallback<URL> = {
            [weak mal, weak self] url, callbackError in
            defer { DispatchQueue.main.async { [weak self] in self?.malUpdateStatus() } }
            var error = callbackError
            
            // If callback url is provided
            if let url = url {
                error = mal?.authenticate(withSSOCallbackUrl: url)
            }
            
            // If an error is present
            if let error = error {
                Log.error("[MyAnimeList.net] Authentication session finished with error: %@", error)
            }
        }
        
        // Open the authentication dialog/web page
        beginWebAuthenticationSession(
            ssoUrl: mal.authenticationUrl,
            callbackScheme: mal.ssoCallbackScheme,
            completion: callback
        )
    }
}

// MARK: - Kitsu specifics
extension TrackingServiceTableViewController {
    private var kitsu: Kitsu { NineAnimator.default.service(type: Kitsu.self) }
    
    private func kitsuPresentAuthenticationPage() {
        let alert = UIAlertController(
            title: "Setup Kitsu.io",
            message: "Login to Kitsu.io with your email and password.",
            preferredStyle: .alert
        )
        
        // Email field
        alert.addTextField {
            $0.placeholder = "example@example.com"
            $0.textContentType = .emailAddress
        }
        
        // Password field
        alert.addTextField {
            $0.placeholder = "Password"
            $0.textContentType = .password
            $0.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "Sign In", style: .default) {
            [unowned kitsu, weak self, unowned alert] _ in
            guard let self = self else { return }
            
            // Obtain username and password values
            guard let user = alert.textFields?.first?.text,
                let password = alert.textFields?.last?.text else {
                return
            }
            
            // Authenticate with the provided username and password
            self.kitsuAuthenticationTask = kitsu.authenticate(user: user, password: password).error {
                [weak self] error in
                // Present the error message
                let errorAlert = UIAlertController(
                    error: error,
                    customTitle: "Authentication Error",
                    allowRetry: false,
                    source: self,
                    completionHandler: nil
                )
                self?.kitsuAuthenticationTask = nil
                
                DispatchQueue.main.async {
                    self?.present(errorAlert, animated: true)
                    self?.kitsuUpdateStatus()
                }
            } .finally {
                [weak self] in
                Log.info("Successfully logged in to Kitsu.io")
                self?.kitsuAuthenticationTask = nil
                DispatchQueue.main.async { self?.kitsuUpdateStatus() }
            }
            self.kitsuUpdateStatus()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func kitsuLogout() {
        kitsu.deauthenticate()
        kitsuUpdateStatus()
    }
    
    private func kitsuUpdateStatus() {
        // First, tint the action label
        kitsuActionLabel.textColor = Theme.current.tint
        
        // Disable the push update switch, since kitsu is implemented as a track-only service
        kitsuPushNineAnimatorUpdatesSwitch.isEnabled = false
        kitsuPushNineAnimatorUpdatesSwitch.setOn(kitsu.didSetup && !kitsu.didExpire, animated: true)
        
        if kitsu.didSetup {
            kitsuStatusLabel.text = "Updating"
            kitsuActionLabel.text = "Sign Out"
            
            // Fetch current user info
            kitsuAccountInfoFetchTask = kitsu.currentUser().error {
                [weak kitsuStatusLabel] _ in DispatchQueue.main.async {
                    kitsuStatusLabel?.text = "Error"
                }
            } .finally {
                [weak kitsuStatusLabel] user in DispatchQueue.main.async {
                    kitsuStatusLabel?.text = "Signed in as \(user.name)"
                }
            }
        } else if kitsuAuthenticationTask != nil {
            kitsuStatusLabel.text = "Updating"
            kitsuActionLabel.text = "Signing you in..."
            kitsuActionLabel.textColor = Theme.current.secondaryText
        } else {
            kitsuStatusLabel.text = "Not Setup"
            kitsuActionLabel.text = "Setup Kitsu.io"
        }
    }
}

// MARK: - AniList.co specifics
extension TrackingServiceTableViewController {
    private var anilist: Anilist { NineAnimator.default.service(type: Anilist.self) }
    
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
                anilistActionLabel.text = "Sign Out"
                
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
        beginWebAuthenticationSession(
            ssoUrl: anilist.ssoUrl,
            callbackScheme: anilist.ssoCallbackScheme,
            completion: callback
        )
    }
    
    // Tell AniList service to logout
    private func anilistLogOut() {
        anilist.deauthenticate()
        anilistUpdateStatus()
    }
}

// MARK: - Simkl.com specifics
extension TrackingServiceTableViewController {
    private var simkl: Simkl { NineAnimator.default.service(type: Simkl.self) }
    
    private func simklUpdateStatus() {
        if simkl.didSetup {
            simklActionLabel.text = "Sign Out"
            simklStatusLabel.text = "Updating"
            
            let updateStatusLabel = {
                text in
                DispatchQueue.main.async { [weak self] in self?.simklStatusLabel.text = text }
            }
            
            simklAccountInfoFetchTask = simkl.currentUser()
                .error { _ in updateStatusLabel("Unavailable") }
                .finally { updateStatusLabel("Signed in as \($0.name)") }
        } else {
            simklStatusLabel.text = "Not Setup"
            simklActionLabel.text = "Setup Simkl.com"
        }
    }
    
    private func simklLogOut() {
        simkl.deauthenticate()
        simklUpdateStatus()
    }
    
    private func simklPresentAuthenticationPage() {
        let callback: NineAnimatorCallback<URL> = {
            [simkl, weak self] url, callbackError in
            defer { DispatchQueue.main.async { [weak self] in self?.simklUpdateStatus() } }
            var error = callbackError
            
            // If callback url is provided
            if let url = url {
                error = simkl.authenticate(withUrl: url)
            }
            
            // If an error is present
            if let error = error {
                Log.error("[Simkl.com] Authentication session finished with error: %@", error)
            }
        }
        
        // Open the authentication dialog/web page
        beginWebAuthenticationSession(
            ssoUrl: simkl.ssoUrl,
            callbackScheme: simkl.ssoCallbackScheme,
            completion: callback
        )
    }
}

// MARK: - Web Authentication Presentation
extension TrackingServiceTableViewController {
    /// Present the Single-Sign-On authentication page
    ///
    /// This method creates the authentication session suitable for the version
    /// of the system and preserves the reference to the session.
    private func beginWebAuthenticationSession(ssoUrl: URL, callbackScheme: String, completion callback: @escaping NineAnimatorCallback<URL>) {
        // Open the authentication dialog/web page
        if #available(iOS 12.0, *) {
            let session = ASWebAuthenticationSession(
                url: ssoUrl,
                callbackURLScheme: anilist.ssoCallbackScheme,
                completionHandler: callback
            )
            
            // Set presentation context provider for authentication
            // session
            if #available(iOS 13.0, *) {
                session.presentationContextProvider = self
            }
            
            // Start the authentication session a`nd store the
            // references
            _ = session.start()
            authenticationSessionReference = session
        } else {
            let session = SFAuthenticationSession(
                url: ssoUrl,
                callbackURLScheme: anilist.ssoCallbackScheme,
                completionHandler: callback
            )
            
            // Start the authentication session and store the
            // references
            _ = session.start()
            authenticationSessionReference = session
        }
    }
}

@available(iOS 12.0, *)
extension TrackingServiceTableViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window!
    }
}
