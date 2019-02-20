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

class InformationSceneSynopsisTableViewCell: UITableViewCell {
    @IBOutlet private weak var collapseExpandButton: UIButton!
    @IBOutlet private weak var synopsisContainer: UITextView!
    @IBOutlet private weak var collapseLayoutConstraint: NSLayoutConstraint?
    
    var onLayoutChange: (() -> Void)?
    
    var information: ListingAnimeInformation? {
        didSet { synopsisContainer.text = information?.description }
    }
    
    private var isCollapsed: Bool = true {
        didSet {
            guard let collapseLayoutConstraint = collapseLayoutConstraint else { return }
            if isCollapsed {
                collapseLayoutConstraint.priority = .defaultHigh
            } else { collapseLayoutConstraint.priority = .defaultLow }
            setNeedsLayout()
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return systemLayoutSizeFitting(size)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let collapseLayoutConstraint = collapseLayoutConstraint else { return }
        collapseExpandButton.isHidden = synopsisContainer.frame.height < collapseLayoutConstraint.constant
    }
    
    @IBAction private func onCollapseExpandButtonTapped(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2) {
            self.isCollapsed.toggle()
            sender.setTitle(self.isCollapsed ? "Expand" : "Collapse", for: .normal)
            self.onLayoutChange?()
        }
    }
}
