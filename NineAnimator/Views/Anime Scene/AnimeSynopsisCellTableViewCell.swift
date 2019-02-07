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

@IBDesignable
class AnimeSynopsisCellTableViewCell: UITableViewCell {
    @IBOutlet private weak var synopsisContainerTextView: UITextView!
    
    @IBOutlet private weak var synopsisContainerConstraint: NSLayoutConstraint!
    
    @IBOutlet private weak var expandCollapseButton: UIButton!
    
    @IBInspectable var collapsedSize: CGFloat = 96
    
    enum State {
        case expanded
        case miniaturized
    }
    
    /// The synopsis itself
    var synopsisText: String? {
        get { return synopsisContainerTextView.text }
        set {
            guard let text = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            synopsisContainerTextView.text = text.isEmpty ? "No synopsis found for this anime" : text
        }
    }
    
    var state: State = .miniaturized {
        didSet {
            expandCollapseButton.setTitle(state == .miniaturized ? "Expand" : "Collapse", for: .normal)
            self.setNeedsUpdateConstraints()
        }
    }
    
    var stateChangeHandler: ((AnimeSynopsisCellTableViewCell) -> Void)?
    
    override func setSelected(_ selected: Bool, animated: Bool) { }
    
    override func updateConstraints() {
        super.updateConstraints()
        
        // This is required for storyboard to work
        synopsisContainerConstraint?.priority = state == .miniaturized ? .defaultHigh : .defaultLow
        
        guard let textView = synopsisContainerTextView else { return }
        
        // Hides expand/collapse button when synopsis is short enough
        expandCollapseButton.isHidden = (textView.sizeThatFits(
            .init(width: textView.frame.width, height: .greatestFiniteMagnitude)
        ).height < synopsisContainerConstraint.constant)
    }
    
    @IBAction private func onExpandButtonTapped(_ sender: Any) {
        UIView.animate(withDuration: 0.2) {
            self.state = self.state == .miniaturized ? .expanded : .miniaturized
            self.stateChangeHandler?(self)
        }
    }
}
