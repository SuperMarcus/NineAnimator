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

class SettingsStorageTipCell: UITableViewCell {
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var tipLabel: UILabel!
    
    func updateMessages(_ state: StorageState, title: String, message: String) {
        switch state { // Set icon according to state
        case .saturated: iconImageView.image = saturatedStateIcon
        case .normal: iconImageView.image = normalStateIcon
        case .unknown: iconImageView.image = unknownStateIcon
        }
        
        // Construct the label with the attributed string
        let attributedString = NSMutableAttributedString(
            string: title + "\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
            ]
        )
        attributedString.append(.init(
            string: " \n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 3, weight: .regular)
            ]
        ))
        attributedString.append(.init(
            string: message,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular)
            ]
        ))
        tipLabel.attributedText = attributedString
    }
    
    // Icons corresponding to the states
    private var saturatedStateIcon: UIImage { #imageLiteral(resourceName: "Yellow Warning") }
    private var normalStateIcon: UIImage { #imageLiteral(resourceName: "Green Checkmark") }
    private var unknownStateIcon: UIImage { #imageLiteral(resourceName: "Green Checkmark") }
    
    enum StorageState {
        case saturated
        case normal
        case unknown
    }
}
