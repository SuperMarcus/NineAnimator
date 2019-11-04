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

import Kingfisher
import UIKit

class LibraryUntrackedReferenceCell: UICollectionViewCell, Themable {
    @IBOutlet private weak var animeTitleLabel: UILabel!
    @IBOutlet private weak var animeArtworkView: UIImageView!
    @IBOutlet private weak var seperatorLineView: UIView!
    @IBOutlet private weak var accessorySubtitleLabel: UILabel!
    
    private(set) var reference: ListingAnimeReference?
    private weak var delegate: LibraryTrackingCollectionController?
    
    /// Initialize this cell
    func setPresenting(_ reference: ListingAnimeReference, delegate: LibraryTrackingCollectionController) {
        self.reference = reference
        self.delegate = delegate
        self.animeTitleLabel.text = reference.name
        self.animeArtworkView.kf.setImage(with: reference.artwork ?? NineAnimator.placeholderArtworkUrl)
    }
    
    func didResolve(relatedTrackingContexts contexts: [TrackingContext]) {
        let mostRecentRecord = contexts.compactMap {
            $0.mostRecentRecord
        } .max { a, b in a.enqueueDate < b.enqueueDate }
        
        if let mostRecentRecord = mostRecentRecord {
            let interval = Date().timeIntervalSince(mostRecentRecord.enqueueDate)
            let intervalLabel: String
            
            switch interval {
            case ..<60: intervalLabel = "within a minute"
            case 60..<(60 * 60): intervalLabel = "\(Int(interval / 60)) minutes ago"
            case (60 * 60)..<(60 * 60 * 24): intervalLabel = "\(Int(interval / (60 * 60))) hours ago"
            default: intervalLabel = "\(Int(interval / (60 * 60 * 24))) days ago"
            }
            
            // Update label
            accessorySubtitleLabel.text = "ep. \(mostRecentRecord.episodeNumber) streamed \(intervalLabel)".uppercased()
        } else { accessorySubtitleLabel.text = "no local records found".uppercased() }
    }
    
    func theme(didUpdate theme: Theme) {
        seperatorLineView.backgroundColor = theme.seperator
    }
}
