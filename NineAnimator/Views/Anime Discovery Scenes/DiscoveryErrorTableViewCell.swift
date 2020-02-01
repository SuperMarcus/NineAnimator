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

class DiscoveryErrorTableViewCell: UITableViewCell {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var errorDescriptionLabel: UILabel!
    @IBOutlet private weak var openLinkButton: UIButton!
    
    typealias ReauthenticationCallback = (Error, DiscoveryErrorTableViewCell) -> Void
    
    private var error: Error?
    private var callback: ReauthenticationCallback?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func setPresenting(_ error: Error, withSource source: RecommendationSource, onReauthenticationRequested callback: @escaping ReauthenticationCallback) {
        self.error = error
        self.callback = callback
        self.titleLabel.text = source.name
        self.errorDescriptionLabel.text = (error as NSError).localizedFailureReason ??  error.localizedDescription
        
        if let error = error as? NineAnimatorError.AuthenticationRequiredError,
            error.authenticationUrl != nil {
            openLinkButton.isHidden = false
        } else { openLinkButton.isHidden = true }
    }
    
    @IBAction private func onReauthenticationButtonTapped(_ sender: Any) {
        if let error = error as? NineAnimatorError.AuthenticationRequiredError {
            callback?(error, self)
        }
    }
}
