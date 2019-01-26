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

import UIKit

class ContentErrorTableViewCell: UITableViewCell, Themable {
    @IBOutlet private weak var searchSubtitleLabel: UILabel!
    
    @IBOutlet private weak var searchTitleLabel: UILabel!
    
    var error: Error? {
        set {
            if let providerError = newValue as? NineAnimatorError {
                switch providerError {
                case .searchError(let error):
                    searchSubtitleLabel.text = error
                default: searchSubtitleLabel.text = providerError.localizedDescription
                }
            } else {
                searchSubtitleLabel.text = newValue?.localizedDescription ?? "Unknown Error"
            }
        }
        get { return nil }
    }
    
    func theme(didUpdate theme: Theme) {
        searchSubtitleLabel.textColor = theme.secondaryText
        searchTitleLabel.textColor = theme.primaryText
        backgroundColor = theme.background
    }
}
