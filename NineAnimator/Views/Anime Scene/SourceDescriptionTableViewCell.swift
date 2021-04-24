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

class SourceDescriptionTableViewCell: UITableViewCell {
    @IBOutlet private weak var sourceHeaderTitle: UILabel!
    @IBOutlet private weak var serverTitleButton: UIButton!
    
    private var onTapHandler: ((UIButton) -> Void)?
    
    func setPresenting(source: Source, server: String, handler: @escaping (UIButton) -> Void) {
        sourceHeaderTitle.text = "Episodes on \(source.name)"
        onTapHandler = handler
        serverTitleButton.setTitle(server, for: .normal)
        
        // Remove separator line for this cell
        separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
        directionalLayoutMargins = .zero
    }
    
    @IBAction private func onServerTitleClicked(_ sender: Any) {
        onTapHandler?(serverTitleButton)
    }
}
