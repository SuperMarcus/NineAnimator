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

class SimpleAnimeTableViewCell: UITableViewCell, Themable {
    private(set) var item: SearchViewController.Item?
    private(set) weak var delegate: SearchViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let trashCanImage = #imageLiteral(resourceName: "baseline_delete_forever_black_24pt")
        let accessoryButton = UIButton()
        accessoryButton.setImage(trashCanImage, for: .normal)
        accessoryButton.setImage(trashCanImage, for: .highlighted)
        accessoryButton.addTarget(self, action: #selector(onDeleteButtonDidTap(_:)), for: .touchUpInside)
        
        self.accessoryView = accessoryButton
    }
    
    /// Initialize the cell with a result item
    func setPresenting(_ item: SearchViewController.Item, delegate: SearchViewController) {
        self.item = item
        self.imageView?.image = item.type.icon
        self.updateText()
        self.pointerEffect.hover()
        self.accessoryView?.isHidden = !item.acceptsDeleteAction
        self.delegate = delegate
    }
    
    func theme(didUpdate theme: Theme) {
        self.imageView?.tintColor = theme.secondaryText
        self.backgroundColor = .clear
        self.accessoryView?.tintColor = theme.secondaryText
        updateText()
    }
    
    func updateText() {
        if let item = item {
            if let link = item.link {
                let label = NSMutableAttributedString(
                    string: link.name,
                    attributes: [
                        .foregroundColor: Theme.current.primaryText,
                        .font: UIFont.systemFont(
                            ofSize: UIFont.systemFontSize,
                            weight: .light
                        )
                    ]
                )
                
                switch item.link {
                case let .anime(animeLink):
                    let sourceName = animeLink.source.name
                    label.append(.init(
                        string: " from \(sourceName)",
                        attributes: [
                            .foregroundColor: Theme.current.secondaryText,
                            .font: UIFont.systemFont(
                                ofSize: UIFont.systemFontSize,
                                weight: .light
                            )
                        ]
                    ))
                default: break
                }
                
                // Update label contents
                textLabel?.attributedText = label
            } else { // Set label to keywords
                textLabel?.attributedText = .init(
                    string: item.keywords,
                    attributes: [
                        .foregroundColor: Theme.current.primaryText,
                        .font: UIFont.systemFont(
                            ofSize: UIFont.systemFontSize,
                            weight: .light
                        )
                    ]
                )
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.accessoryView?.sizeToFit()
    }
    
    @objc fileprivate func onDeleteButtonDidTap(_ senser: UIButton) {
        if let item = self.item, let delegate = self.delegate {
            delegate.searchViewItemCell(self, deleteItem: item)
        }
    }
}
