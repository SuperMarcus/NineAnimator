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
import ViewAnimator

class SetupFinishingViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // If on a large screen device, allow any screen orientations
        if traitCollection.horizontalSizeClass == .regular &&
            traitCollection.verticalSizeClass == .regular {
            return .all
        }
        
        // Else only allows portrait
        return .portrait
    }
    
    @IBOutlet private weak var finishTitleLabel: UILabel!
    @IBOutlet private weak var finishSubtitleLabel: UILabel!
    @IBOutlet private weak var finishButton: UIButton!
    @IBOutlet private weak var openDiscordButton: UIButton!
    
    private var didShowAnimations = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !didShowAnimations {
            finishTitleLabel.alpha = 0
            finishSubtitleLabel.alpha = 0
            finishButton.alpha = 0
            openDiscordButton.alpha = 0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !didShowAnimations {
            didShowAnimations = true
            
            finishTitleLabel.animate(animations: [ AnimationType.from(direction: .top, offset: 16) ], duration: 0.5)
            finishSubtitleLabel.animate(animations: [ AnimationType.from(direction: .bottom, offset: 16) ], duration: 0.5)
            openDiscordButton.animate(animations: [ AnimationType.from(direction: .bottom, offset: 16) ], duration: 0.5)
            finishButton.animate(animations: [], delay: 0)
        }
    }
    
    @IBAction private func onFinishButtonTapped(_ sender: Any) {
        NineAnimator.default.user.markDidSetupLatestVersion()
        dismiss(animated: true)
    }
    
    @IBAction private func onOpenDiscordButtonTapped(_ sender: Any) {
        UIApplication.shared.open(NineAnimator.discordServerInvitationUrl, options: [:], completionHandler: nil)
    }
}
