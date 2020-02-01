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

/// Configure the user interface style to the proper value for a View Controller
func configureStyleOverride(_ viewController: UIViewController, withTheme theme: Theme = .current) {
    if #available(iOS 13.0, *) {
        // If dynamic appearance is enabled, use system interface style
        if NineAnimator.default.user.dynamicAppearance {
            viewController.overrideUserInterfaceStyle = .unspecified
        } else { viewController.overrideUserInterfaceStyle = interfaceStyle(for: theme) }
    }
}

/// Configure the user interface style to the proper value for a View
func configureStyleOverride(_ view: UIView, withTheme theme: Theme = .current) {
    if #available(iOS 13.0, *) {
        view.overrideUserInterfaceStyle = interfaceStyle(for: theme)
    }
}

/// Obtain the appropriate `UIUserInterfaceStyle` value for the theme
@available(iOS 13.0, *)
private func interfaceStyle(for theme: Theme) -> UIUserInterfaceStyle {
    switch theme.name {
    case "dark": return .dark
    case "light": return .light
    default:
        Log.error("[StyleOverride] Unknown preferred interface style for appearance: %@", theme.name)
        return .unspecified
    }
}
