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

import SafariServices
import UIKit

extension UIAlertController {
    /// Initialize a ready-to-present UIAlertController with all the
    /// UIAlertAction installed for the error.
    convenience init(error: Error,
                     customTitle: String? = nil,
                     allowRetry: Bool = false,
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
                    let authenticationController = SFSafariViewController(url: authenticationUrl)
                    
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
                self.addAction(UIAlertAction(title: "Retry", style: .default) {
                    _ in completionHandler?(true)
                })
            }
        }
    }
}
