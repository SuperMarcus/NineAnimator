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

import UIKit

protocol BlendInViewController { }

class ApplicationNavigationController: UINavigationController, UINavigationControllerDelegate, Themable {
    override func viewDidLoad() {
        super.viewDidLoad()
        Theme.provision(self)
        delegate = self
    }
    
    func theme(didUpdate theme: Theme) {
        navigationBar.barStyle = theme.barStyle
        navigationBar.barTintColor = theme.background
        
        view.tintColor = theme.tint
        view.backgroundColor = theme.background
    }
    
    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        // Disable shadow image and set to not translucent when trying to blend in
        // the navigation bar and the contents
        navigationBar.shadowImage = viewController is BlendInViewController ? UIImage() : nil
        navigationBar.isTranslucent = !(viewController is BlendInViewController)
    }
}
