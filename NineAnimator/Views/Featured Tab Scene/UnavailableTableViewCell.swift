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

class UnavailableTableViewCell: UITableViewCell, Themable {
    @IBOutlet private weak var unavailableErrorTitleLabel: UILabel!
    @IBOutlet private weak var unavailableErrorMessageLabel: UILabel!
    @IBOutlet private weak var resolveErrorButton: UIButton!
    
    var error: Error? {
        didSet {
            guard let error = error else { return }
            unavailableErrorMessageLabel.text = error.localizedDescription
            resolveErrorButton.isHidden = (error as? NineAnimatorError.AuthenticationRequiredError)?.authenticationUrl == nil
        }
    }
    
    func theme(didUpdate theme: Theme) {
        unavailableErrorTitleLabel.textColor = theme.primaryText
        unavailableErrorMessageLabel.textColor = theme.secondaryText
    }
}
