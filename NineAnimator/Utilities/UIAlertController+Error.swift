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
import SafariServices
import UIKit

extension UIAlertController {
    /// Initialize a ready-to-present UIAlertController from an error.
    /// - Parameter error: The error object to be presented.
    /// - Parameter customTitle: A custom title to be shown on the alert. Defaults to "Authentication Required" if `nil`.
    /// - Parameter allowRetry: Specify if the alert should include a retry action. This parameter is ignored if `error` inherits from `NineAnimatorError.AuthenticationRequiredError`, in which case an `Open` button will be shown if `authenticationUrl` is set for the error.
    /// - Parameter retryActionName: Specify the text on the retry button. This parameter is ignored if `error` inherits from `NineAnimatorError.AuthenticationRequiredError`.
    /// - Parameter source: Specify the source view controller for presenting additional components (such as the authentication scene). A `nil` value will direct the controller to present additional scenes with `RootViewController.shared?.presentOnTop()`.
    /// - Parameter completionHandler: The completion handler. `true` means the user intends to retry the task or an authentication has been completed.
    convenience init(error: Error,
                     customTitle: String? = nil,
                     allowRetry: Bool = false,
                     retryActionName: String = "Retry",
                     source: UIViewController? = nil,
                     completionHandler: ((Bool) -> Void)? = nil) {
        let errorMessage: String = {
            let message = error.localizedDescription
            if let reason = (error as NSError).localizedFailureReason {
                return "\(message): \(reason)"
            } else { return message }
        }()
        
        // If the error is an authentication required error, see if we can
        // present the open link handler
        if let error = error as? NineAnimatorError.AuthenticationRequiredError {
            self.init(
                title: customTitle ?? "Authentication Required",
                message: errorMessage,
                preferredStyle: .alert
            )
            
            // Cancel action
            self.addAction(UIAlertAction(title: "Cancel", style: .cancel) {
                _ in completionHandler?(false)
            })
            
            // If the authentication url exists, present the option to open the link
            if let authenticationUrl = error.authenticationUrl {
                self.addAction(UIAlertAction(title: "Open", style: .default) {
                    _ in
//                    let authenticationController = SFSafariViewController(url: authenticationUrl)
                    let authenticationController = NAAuthenticationViewController
                        .create(
                            authenticationUrl,
                            withUserAgent: error.relatedRequestManager?.currentIdentity ?? (error.sourceOfError as? BaseSource)?.sessionUserAgent
                        ) { completionHandler?(true) }
                    
                    // If no source view controller is present, use the RootViewController's shared
                    // present on top method to present the authentication page
                    if let source = source {
                        source.present(authenticationController, animated: true) {
                            // Call completion handler with true
                            completionHandler?(true)
                        }
                    } else {
                        RootViewController.shared?.presentOnTop(authenticationController, animated: true) {
                            // Call completion handler with true
                            completionHandler?(true)
                        }
                    }
                })
            }
        } else {
            self.init(
                title: customTitle ?? "Error",
                message: errorMessage,
                preferredStyle: .alert
            )
            
            // Ok action
            self.addAction(UIAlertAction(title: "Ok", style: .cancel) {
                _ in completionHandler?(false)
            })
            
            // Add the retry option if retry is allowed
            if allowRetry {
                self.addAction(UIAlertAction(title: retryActionName, style: .default) {
                    _ in completionHandler?(true)
                })
            }
        }
    }
}
