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

import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources
import UIKit

class SettingsAppIconAlternativeIconCell: UICollectionViewCell, Themable {
    private(set) var representingIconName: String?
    private(set) var isCurrentlySelected = false
    
    @IBOutlet private var iconNameLabel: UILabel!
    @IBOutlet private var iconPreviewView: UIImageView!
    @IBOutlet private var iconContentView: UIView!
    
    override func prepareForReuse() {
        iconPreviewView.layer.borderColor = Theme.current.background.cgColor
        isCurrentlySelected = false
    }
    
    func setPresenting(_ alternativeIconName: String?, isUnlocked: Bool) {
        if !isUnlocked {
            iconPreviewView.image = #imageLiteral(resourceName: "Unknwon Square")
        } else if let alternativeIconName = alternativeIconName,
           let iconResource = Bundle.main.url(forResource: "\(alternativeIconName)@3x", withExtension: "png") {
            iconPreviewView.kf.setImage(with: iconResource)
        } else {
            iconPreviewView.image = #imageLiteral(resourceName: "High Resolution App Icon")
        }
        
        iconNameLabel.text = isUnlocked ? alternativeIconName ?? "Default" : "?"
    }
    
    func setIsCurrentIcon(_ isCurrent: Bool, animated: Bool) {
        self.isCurrentlySelected = isCurrent
        
        let currentColor = self.iconContentView.layer.borderColor ?? Theme.current.background.cgColor
        let targetColor = self.isCurrentlySelected ? Theme.current.tint.cgColor : Theme.current.background.cgColor
        
        if animated {
            let animation = CABasicAnimation(keyPath: "borderColor")
            animation.fromValue = currentColor
            animation.toValue = targetColor
            animation.duration = 0.2
            animation.fillMode = .forwards
            self.iconContentView.layer.add(animation, forKey: "settings.animation.borderColor")
        }
        
        self.iconContentView.layer.borderColor = targetColor
    }
    
    func theme(didUpdate theme: Theme) {
        if let iconContentView = iconContentView {
            iconContentView.layer.borderColor = isCurrentlySelected ? theme.tint.cgColor : theme.background.cgColor
        }
    }
}
