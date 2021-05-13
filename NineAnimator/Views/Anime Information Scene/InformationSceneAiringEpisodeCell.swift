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

class InformationSceneAiringEpisodeCell: UICollectionViewCell {
    @IBOutlet private var episodeDescriptionLabel: UILabel!
    @IBOutlet private var remainingTimeLabel: UILabel!
    @IBOutlet private var airingTimeLabel: UILabel!
    
    private(set) var airingEpisode: ListingAiringEpisode?
    
    func setPresenting(_ airingEpisode: ListingAiringEpisode) {
        self.airingEpisode = airingEpisode
        self.episodeDescriptionLabel.text = "Episode \(airingEpisode.episodeNumber) airing in"
        
        let remainingTimeFormatter = DateComponentsFormatter()
        remainingTimeFormatter.unitsStyle = .full
        remainingTimeFormatter.includesApproximationPhrase = false
        remainingTimeFormatter.includesTimeRemainingPhrase = false
        remainingTimeFormatter.maximumUnitCount = 2
        remainingTimeFormatter.allowedUnits = [.hour, .day, .minute]
        
        self.remainingTimeLabel.text = remainingTimeFormatter.string(
            from: airingEpisode.scheduled.timeIntervalSinceNow
        )
        
        let airingDateFormatter = DateFormatter()
        airingDateFormatter.dateStyle = .full
        airingDateFormatter.timeStyle = .none
        
        self.airingTimeLabel.text = airingDateFormatter.string(
            from: airingEpisode.scheduled
        )
    }
}
