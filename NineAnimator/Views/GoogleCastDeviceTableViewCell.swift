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

import OpenCastSwift
import UIKit

class GoogleCastDeviceTableViewCell: UITableViewCell {
    @IBOutlet private weak var connectingIndicator: UIActivityIndicatorView!
    
    weak var delegate: GoogleCastMediaPlaybackViewController?
    
    var device: CastDevice? {
        didSet {
            guard let device = device else { return }
            deviceNameLabel.text = device.name
            deviceModelLabel.text = device.modelName
        }
    }
    
    var state: CastDeviceState = .idle {
        didSet {
            switch state {
            case .idle:
                accessoryType = .none
                connectingIndicator.stopAnimating()
                connectingIndicator.isHidden = true
            case .connecting:
                accessoryType = .none
                connectingIndicator.startAnimating()
                connectingIndicator.isHidden = false
            case .connected:
                accessoryType = .checkmark
                connectingIndicator.stopAnimating()
                connectingIndicator.isHidden = true
            }
            setNeedsLayout()
        }
    }
    
    @IBOutlet private weak var deviceNameLabel: UILabel!
    @IBOutlet private weak var deviceModelLabel: UILabel!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        delegate?.device(selected: selected, from: device!, with: self)
    }
}
