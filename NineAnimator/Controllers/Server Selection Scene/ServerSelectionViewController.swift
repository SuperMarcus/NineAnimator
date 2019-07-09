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

class ServerSelectionViewController: UIViewController {
    @IBOutlet private weak var selectionView: ServerSelectionView!
    private var completionHandler: ((ServerSelectionViewController) -> Void)?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.current.preferredStatusBarStyle
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = .init(width: 360, height: 500)
        selectionView.makeThemable()
    }
    
    @IBAction private func onDoneButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        completionHandler?(self)
    }
    
    class func presentSelectionDialog(from vc: UIViewController? = nil, completionHandler: ((ServerSelectionViewController) -> Void)? = nil) {
        if let viewController = UIStoryboard(name: "ServerSelection", bundle: .main).instantiateInitialViewController() as? ServerSelectionViewController {
            // Set presentation style
            viewController.modalPresentationStyle = .formSheet
            viewController.completionHandler = completionHandler
            
            // Present the view controller
            if let sourceVc = vc {
                sourceVc.present(viewController, animated: true)
            } else { RootViewController.shared?.presentOnTop(viewController) }
        }
    }
}
