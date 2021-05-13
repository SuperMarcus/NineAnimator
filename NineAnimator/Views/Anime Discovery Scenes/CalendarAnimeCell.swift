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

import Kingfisher
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources
import UIKit

class CalendarAnimeCell: UICollectionViewCell, Themable {
    @IBOutlet private weak var backgroundContainerView: UIView!
    @IBOutlet private weak var scheduledItemImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var timeLabel: UILabel!
    
    private(set) var representingScheduledAnime: AnimeScheduleCollectionViewController.ScheduledAnime?
    private(set) weak var delegate: AnimeScheduleCollectionViewController?
    
    override var isHighlighted: Bool {
        get { super.isHighlighted }
        set {
            super.isHighlighted = newValue
            
            // Animate scale
            UIView.animate(withDuration: 0.2) {
                [weak self] in
                self?.transform = newValue ? .init(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        makeThemable()
    }
    
    func setPresenting(_ item: AnimeScheduleCollectionViewController.ScheduledAnime, withDelegate delegate: AnimeScheduleCollectionViewController) {
        self.representingScheduledAnime = item
        self.delegate = delegate
        
        // Set poster image
        self.scheduledItemImageView.kf.setImage(
            with: item.link.artwork,
            options: [ .transition(.fade(0.3)) ]
        )
        self.titleLabel.text = item.presentationTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subtitleLabel.text = item.presentationSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .long
        self.timeLabel.text = formatter.string(from: item.broadcastDate)
        self.pointerEffect.hover(scale: true)
    }
    
    func theme(didUpdate theme: Theme) {
        backgroundContainerView.backgroundColor = theme.secondaryBackground
        timeLabel.textColor = theme.tint
    }
}
