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
import UIKit

class LibraryDownloadingAnimeCell: UICollectionViewCell {
    private(set) var animeLink: AnimeLink?
    
    @IBOutlet private weak var animeArtworkImage: UIImageView!
    @IBOutlet private weak var animeTitleLabel: UILabel!
    @IBOutlet private weak var subtitleAccessoryLabel: UILabel!
    @IBOutlet private weak var downloadProgressLabel: UILabel!
    @IBOutlet private weak var downloadProgressBar: UIProgressView!
    @IBOutlet private weak var animeSourceLabel: UILabel!
    
    func setPresenting(_ statefulAnime: AnimeLink) {
        self.animeLink = statefulAnime
        self.animeArtworkImage.kf.setImage(with: statefulAnime.image)
        self.animeTitleLabel.text = statefulAnime.title
        self.animeSourceLabel.text = statefulAnime.source.name
        self.updateStates()
        self.pointerEffect.hover(scale: true)
    }
    
    func updateStates() {
        if let animeLink = animeLink {
            let inProgressContents = OfflineContentManager.shared.contents(for: animeLink)
            var finishedEpisodes = 0
            var inProgressEpisodes = 0
            
            let overallProgress = inProgressContents.reduce(Float(0.0)) {
                accumulatedProgress, content in
                switch content.state {
                case .preservationInitiated:
                    inProgressEpisodes += 1
                    return accumulatedProgress
                case let .preserving(progress):
                    inProgressEpisodes += 1
                    return accumulatedProgress + progress
                case .preserved:
                    finishedEpisodes += 1
                    return accumulatedProgress + 1
                default: return accumulatedProgress
                }
            } / Float(inProgressContents.count)
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = 1
            formatter.percentSymbol = "%"
            
            let progressPercentString = overallProgress == 1 ? "Available": (formatter.string(
                from: NSNumber(value: overallProgress)
            ) ?? "Unknown")
            
            self.downloadProgressBar.setProgress(overallProgress, animated: true)
            self.downloadProgressLabel.text = progressPercentString
            
            var progressDescriptionSnippets = [String]()
            
            if inProgressEpisodes > 0 {
                progressDescriptionSnippets.append("\(inProgressEpisodes) in progress")
            }
            
            if finishedEpisodes > 0 {
                progressDescriptionSnippets.append("\(finishedEpisodes) available")
            }
            
            self.subtitleAccessoryLabel.text = progressDescriptionSnippets
                .joined(separator: ", ")
                .uppercased()
        }
    }
    
    override var isHighlighted: Bool {
        didSet { updateTouchReactionTint() }
    }
    
    override var isSelected: Bool {
        didSet { updateTouchReactionTint() }
    }
    
    private func updateTouchReactionTint() {
        let shouldTint = isHighlighted || isSelected
        alpha = shouldTint ? 0.4 : 1
    }
}
