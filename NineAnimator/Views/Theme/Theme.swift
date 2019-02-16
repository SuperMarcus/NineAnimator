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
    
    let secondaryBackground: UIColor
    
    let tint: UIColor
    
    let seperator: UIColor
    
    let blurStyle: UIBlurEffect.Style
    
    let barStyle: UIBarStyle
    
    let backgroundBlurStyle: UIBlurEffect.Style
    
    let scrollIndicatorStyle: UIScrollView.IndicatorStyle
    
    let activityIndicatorStyle: UIActivityIndicatorView.Style
    
    let keyboardAppearance: UIKeyboardAppearance
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
        provisionedThemables.insert(ThemableContainer(themable: themable, view: nil))
        themable.theme(didUpdate: current)
    }
    
    static func provision(view: UIView) {
        collectGarbage()
        provisionedThemables.insert(ThemableContainer(themable: nil, view: view))
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
            view.separatorColor = theme.seperator
            
            if view.style == .grouped {
                view.backgroundColor = theme.secondaryBackground
            } else { view.backgroundColor = theme.background }
        }
        
        if let view = view as? UITableViewCell {
            if view.tintText {
                view.textLabel?.textColor = theme.tint
            } else { view.textLabel?.textColor = theme.primaryText }
            
            view.detailTextLabel?.textColor = theme.secondaryText
            view.backgroundColor = theme.background
            view.contentView.backgroundColor = .clear
        }
        
        if let view = view as? UILabel {
            view.textColor = view.isPrimaryText ? theme.primaryText : theme.secondaryText
            view.backgroundColor = .clear
        }
        
        if let view = view as? UIActivityIndicatorView {
            view.style = theme.activityIndicatorStyle
            view.backgroundColor = .clear
        }
        
        if let view = view as? UITextView {
            view.textColor = theme.primaryText
            view.backgroundColor = .clear
        }
        
        if let view = view as? UIProgressView {
            view.progressTintColor = theme.tint
            view.trackTintColor = theme.secondaryText.withAlphaComponent(0.6)
            view.backgroundColor = .clear
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
            secondaryBackground: UIColor.groupTableViewBackground,
            tint: #colorLiteral(red: 0.07843137255, green: 0.5568627451, blue: 1, alpha: 1),
            seperator: #colorLiteral(red: 0.6666666865, green: 0.6666666865, blue: 0.6666666865, alpha: 1),
            blurStyle: .extraLight,
            barStyle: .default,
            backgroundBlurStyle: .dark,
            scrollIndicatorStyle: .black,
            activityIndicatorStyle: .gray,
            keyboardAppearance: .light
        )
        
        let dark = Theme(
            name: "dark",
            primaryText: #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1),
            secondaryText: #colorLiteral(red: 0.6666666865, green: 0.6666666865, blue: 0.6666666865, alpha: 1),
            background: #colorLiteral(red: 0.1600990295, green: 0.1600990295, blue: 0.1600990295, alpha: 1),
            secondaryBackground: #colorLiteral(red: 0.1326085031, green: 0.1326085031, blue: 0.1326085031, alpha: 1),
            tint: #colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1),
            seperator: #colorLiteral(red: 0.3333333433, green: 0.3333333433, blue: 0.3333333433, alpha: 1),
            blurStyle: .dark,
            barStyle: .black,
            backgroundBlurStyle: .regular,
            scrollIndicatorStyle: .white,
            activityIndicatorStyle: .white,
            keyboardAppearance: .dark
        )
        
        return [ light.name: light, dark.name: dark ]
    }()
    
    private static var provisionedThemables = Set<ThemableContainer>()
    
    private static func collectGarbage() {
        provisionedThemables = provisionedThemables.filter { $0.themable != nil || $0.view != nil }
    }
    
    private struct ThemableContainer: Hashable {
        weak var themable: Themable?
        
        weak var view: UIView?
        
        func hash(into hasher: inout Hasher) {
            if let view = view {
                hasher.combine(view)
            }
            
            if let themable = themable {
                let identifier = ObjectIdentifier(themable)
                hasher.combine(identifier)
            }
        }
        
        static func == (_ lhs: Theme.ThemableContainer, _ rhs: Theme.ThemableContainer) -> Bool {
            return lhs.hashValue == rhs.hashValue
        }
    }
}

// MARK: - Theme: Equatable
extension Theme: Equatable {
    static func == (_ lhs: Theme, _ rhs: Theme) -> Bool {
        return lhs.name == rhs.name
    }
}
