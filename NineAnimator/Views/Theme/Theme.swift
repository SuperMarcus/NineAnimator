//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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

import Foundation
import UIKit

protocol Themable: AnyObject {
    func theme(didUpdate theme: Theme)
}

struct Theme {
    let name: String
    
    let primaryText: UIColor
    
    let secondaryText: UIColor
    
    let background: UIColor
    
    let tint: UIColor
    
    let blurStyle: UIBlurEffect.Style
    
    let barStyle: UIBarStyle
    
    let backgroundBlurStyle: UIBlurEffect.Style
    
    let scrollIndicatorStyle: UIScrollView.IndicatorStyle
}

// MARK: - Accessing Theme object
extension Theme {
    private(set) static var current: Theme = {
        if let theme = Theme.availableThemes[NineAnimator.default.user.theme] {
            return theme
        } else { return Theme.availableThemes.first!.value }
    }()
    
    static func provision(_ themable: Themable) {
        collectGarbage()
        provisionedThemables.append(ThemableContainer(themable: themable, view: nil))
        themable.theme(didUpdate: current)
    }
    
    static func provision(view: UIView) {
        collectGarbage()
        provisionedThemables.append(ThemableContainer(themable: nil, view: view))
        update(current, for: view)
    }
    
    static func setTheme(_ theme: Theme, animated: Bool = true) {
        collectGarbage()
        NineAnimator.default.user.theme = theme.name
        Theme.current = theme
        if animated {
            UIView.animate(withDuration: 0.2) {
                provisionedThemables.forEach {
                    $0.themable?.theme(didUpdate: theme)
                    update(theme, for: $0.view)
                }
            }
        } else {
            provisionedThemables.forEach {
                $0.themable?.theme(didUpdate: theme)
                update(theme, for: $0.view)
            }
        }
    }
    
    private static func update(_ theme: Theme, for view: UIView?) {
        view?.backgroundColor = theme.background
        view?.tintColor = theme.tint
        
        if let view = view as? UITableView {
            view.indicatorStyle = theme.scrollIndicatorStyle
            view.backgroundColor = theme.background
        }
        
        if let view = view as? UITableViewCell {
            view.textLabel?.textColor = theme.primaryText
            view.detailTextLabel?.textColor = theme.secondaryText
            view.backgroundColor = theme.background
        }
    }
}

// MARK: - Definining and managing themes
extension Theme {
    private(set) static var availableThemes: [String: Theme] = {
        let light = Theme(
            name: "light",
            primaryText: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),
            secondaryText: #colorLiteral(red: 0.6352941176, green: 0.6352941176, blue: 0.6549019608, alpha: 1),
            background: #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1),
            tint: #colorLiteral(red: 0.07843137255, green: 0.5568627451, blue: 1, alpha: 1),
            blurStyle: .extraLight,
            barStyle: .default,
            backgroundBlurStyle: .dark,
            scrollIndicatorStyle: .black
        )
        
        let dark = Theme(
            name: "dark",
            primaryText: #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1),
            secondaryText: #colorLiteral(red: 0.6666666865, green: 0.6666666865, blue: 0.6666666865, alpha: 1),
            background: #colorLiteral(red: 0.1176470588, green: 0.1176470588, blue: 0.1176470588, alpha: 1),
            tint: #colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1),
            blurStyle: .dark,
            barStyle: .black,
            backgroundBlurStyle: .regular,
            scrollIndicatorStyle: .white
        )
        
        return [ light.name: light, dark.name: dark ]
    }()
    
    private static var provisionedThemables = [ThemableContainer]()
    
    private static func collectGarbage() {
        provisionedThemables = provisionedThemables.filter { $0.themable != nil || $0.view != nil }
    }
    
    private struct ThemableContainer {
        weak var themable: Themable?
        
        weak var view: UIView?
    }
}
