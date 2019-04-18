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

// Disable literal linting because it's easy to confuse the
// quickaction icon with the other icons
// swiftlint:disable object_literal

// MARK: - Quick action
extension DiscoverySceneViewController {
    struct QuickAction {
        var icon: UIImage
        var title: String
        var onAction: () -> Void
    }
    
    var availableQuickActions: [QuickAction] {
        var listOfActions = [QuickAction]()
        
        // Add resume playback button
        if let lastPlayedEpisodeLink = NineAnimator.default.user.lastEpisode,
            lastPlayedEpisodeLink.playbackProgress < 0.8 {
            listOfActions.append(
                .init(
                    icon: UIImage(named: "Play Icon QuickAction")!,
                    title: "Continue Playback"
                ) { RootViewController.open(whenReady: .episode(lastPlayedEpisodeLink)) }
            )
        }
        
        listOfActions.append(
            .init(
                icon: UIImage(named: "Cog Icon QuickAction")!,
                title: "Preferences"
            ) {
                [weak self] in
                guard let self = self else { return }
                if let viewController = SettingsRootTableViewController.create() {
                    self.present(viewController, animated: true)
                }
            }
        )
        
        listOfActions.append(
            .init(
                icon: UIImage(named: "Chromecast Icon QuickAction")!,
                title: "Setup Cast"
            ) { CastController.default.presentPlaybackController() }
        )
        
        return listOfActions
    }
}
