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

class AnimePredictedEpisodeTableViewCell: UITableViewCell {
    @IBOutlet private weak var suggestingTitleLabel: UILabel!
    
    @IBOutlet private weak var suggestingEpisodeNameLabel: UILabel!
    
    /// The link to the episode that this cell is suggesting
    var episodeLink: EpisodeLink? {
        didSet {
            guard let link = episodeLink else { return }
            suggestingEpisodeNameLabel.text = "Episode \(link.name)"
        }
    }
    
    /// The reason that the episode is suggested
    ///
    /// - Important: Set the `episodeLink` property before updating this property
    var reason: SuggestionReason = .start {
        didSet {
            switch reason {
            case .start: suggestingTitleLabel.text = "Start Watching"
            case .continue:
                if let link = episodeLink {
                    switch link.playbackProgress {
                    case 0.9...: suggestingTitleLabel.text = "Watch Again"
                    case 0.6...0.9: suggestingTitleLabel.text = "Finish Watching"
                    default: suggestingTitleLabel.text = "Continue Watching"
                    }
                } else { suggestingTitleLabel.text = "Continue Watching" }
            }
        }
    }
}

extension AnimePredictedEpisodeTableViewCell {
    enum SuggestionReason {
        case start      // Suggesting to start the episode
        case `continue` // Suggesting to continue the episode
    }
}
