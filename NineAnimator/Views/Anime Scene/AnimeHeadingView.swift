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

@IBDesignable
class AnimeHeadingView: UIView {
    /// Set before the anime is loaded
    var animeLink: AnimeLink? {
        didSet {
            guard let animeLink = animeLink else { return }
            
            // Basic anime information
            animeTitleLabel.text = animeLink.title
            animeAliasLabel.text = "" // Set alias label to empty
            posterImageView.kf.setImage(with: animeLink.image)
            
            // Subscription status - Hide subscribe button when is subscribed
            isSubscribedLabel.alpha = NineAnimator.default.user.isSubscribing(anime: animeLink) ? 1.0 : 0.0
            subscriptionButton.alpha = NineAnimator.default.user.isSubscribing(anime: animeLink) ? 0.0 : 1.0
            
            // Change the bottom space based on if the button is present or not
            serverInformationBottomLayoutConstraint.priority = NineAnimator.default.user.isSubscribing(anime: animeLink) ?
                .init(rawValue: 900) : .defaultLow
            serverInformationRightLayoutConstraint.priority = NineAnimator.default.user.isSubscribing(anime: animeLink) ?
                .defaultHigh : .defaultLow
            
            // Layout
            setNeedsLayout()
            sizeToFit()
        }
    }
    
    /// Set after the anime is successfully loaded
    var anime: Anime? {
        didSet {
            guard let anime = anime else { return }
            animeLink = anime.link // Update poster and title fetched from the new anime link
            animeAliasLabel.text = anime.alias
            
            if let ratings = anime.additionalAttributes[.rating] as? Float,
                let ratingsScale = anime.additionalAttributes[.ratingScale] as? Float {
                animeRatingView.update(rating: ratings, scale: ratingsScale)
            } else { animeRatingView.update() }
            
            if let airDate = anime.additionalAttributes[.airDate] as? String {
                animeAirDateView.update(airDate)
            } else { animeAirDateView.update() }
            
            // Layout
            setNeedsLayout()
            sizeToFit()
        }
    }
    
    var selectedServerName: String? {
        didSet {
            if let name = selectedServerName {
                serverNameLabel.text = "Displaying episodes available on \(name)"
            } else { serverNameLabel.text = "Server can be selected during playback" }
        }
    }
    
    @IBOutlet private weak var posterImageView: UIImageView!
    
    @IBOutlet private weak var animeTitleLabel: UILabel!
    
    @IBOutlet private weak var animeAliasLabel: UILabel!
    
    @IBOutlet private weak var isSubscribedLabel: UILabel!
    
    @IBOutlet private weak var serverNameLabel: UILabel!
    
    @IBOutlet private weak var subscriptionButton: UIButton!
    
    @IBOutlet private weak var animeRatingView: AnimeRatingView!
    
    @IBOutlet private weak var animeAirDateView: AnimeAirDateView!
    
    @IBOutlet private weak var extraInformationContainer: UIView!
    
    @IBOutlet private weak var serverInformationBottomLayoutConstraint: NSLayoutConstraint!
    
    @IBOutlet private weak var serverInformationRightLayoutConstraint: NSLayoutConstraint!
    
    /// Refresh the states and information
    func update(animated: Bool = false, updates: ((AnimeHeadingView) -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if animated {
                UIView.animate(withDuration: 0.2) {
                    updates?(self)
                    
                    if let anime = self.anime {
                        self.anime = anime
                    } else if let animeLink = self.animeLink {
                        self.animeLink = animeLink
                    }
                    
                    // Update server name
                    if let serverName = self.selectedServerName {
                        self.selectedServerName = serverName
                    }
                    
                    self.sizeToFit()
                    self.setNeedsLayout()
                }
            } else {
                updates?(self)
                
                if let anime = self.anime {
                    self.anime = anime
                } else if let animeLink = self.animeLink {
                    self.animeLink = animeLink
                }
                
                // Update server name
                if let serverName = self.selectedServerName {
                    self.selectedServerName = serverName
                }
            }
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitSize = systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(width: size.width, height: fitSize.height)
    }
}
