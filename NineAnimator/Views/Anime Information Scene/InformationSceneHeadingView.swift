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

class InformationSceneHeadingView: UIView, Themable {
    @IBOutlet private weak var topImageView: UIImageView!
    @IBOutlet private weak var animeArtworkImageView: UIImageView!
    @IBOutlet private weak var animeTitleLabel: UILabel!
    @IBOutlet private weak var animeAlternativeTitleLabel: UILabel!
    @IBOutlet private weak var showEpisodesButton: UIButton!
    @IBOutlet private weak var optionsButton: UIButton!
    
    private var reference: ListingAnimeReference?
    private weak var imageMaskLayer: CAGradientLayer?
    private var topImageOriginalFrame: CGRect?
    
    /// A callback closure when the layout of the heading view has changed
    var onNeededLayout: (() -> Void)?
    
    /// Suggested navigation bar transitioning height in the parent view's
    /// coordinate system
    var suggestedTransitionHeight: CGFloat {
        frame.origin.y + (topImageView.frame.height / 2)
    }
    
    /// A negative value indicating how much the user had scrolled passed
    /// the boundary
    var headingScrollExpansion: CGFloat = 0 {
        didSet {
            guard let oFrame = topImageOriginalFrame else { return }
            topImageView.frame = CGRect(
                x: oFrame.origin.x,
                y: oFrame.origin.y + headingScrollExpansion,
                width: oFrame.size.width,
                height: oFrame.size.height - headingScrollExpansion
            )
            imageMaskLayer?.frame = topImageView.bounds
            imageMaskLayer?.speed = 10 // Make the image mask layer speed faster
        }
    }
    
    func initialize(withReference reference: ListingAnimeReference) {
        self.reference = reference
        animeTitleLabel.text = reference.name
        animeAlternativeTitleLabel.text = "Loading..." // Set alternative title to an empty string
        
        // Disable buttons
        showEpisodesButton.isEnabled = false
        optionsButton.isEnabled = false
        
        animeArtworkImageView.alpha = 0.0
        animeArtworkImageView.kf.setImage(with: reference.artwork, progressBlock: nil) {
            [weak animeArtworkImageView] _ in
            UIView.animate(withDuration: 0.1) {
                animeArtworkImageView?.alpha = 1.0
            }
        }
    }
    
    func update(with animeInformation: ListingAnimeInformation) {
        if let wallpaper = animeInformation.wallpapers.first {
            topImageView.alpha = 0.0
            topImageView.kf.setImage(with: wallpaper, progressBlock: nil) {
                [weak topImageView] _ in UIView.animate(withDuration: 1) {
                    topImageView?.alpha = 0.4
                }
            }
        }
        
        UIView.animate(withDuration: 0.2) {
            [weak self] in
            // Set alternative titles
            let allName = animeInformation.name
            self?.animeAlternativeTitleLabel.text = [ allName.english, allName.romaji, allName.native ]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: "; ")
            
            // Enable buttons
            self?.showEpisodesButton.isEnabled = true
            self?.optionsButton.isEnabled = true
            
            // Tell parent that layout is needed
            self?.onNeededLayout?()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Add gradient layer to the image view
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = topImageView.bounds
        gradientLayer.locations = [0.4, 1.0]
        gradientLayer.colors = [UIColor.white.cgColor, UIColor.clear.cgColor]
        topImageView.layer.mask = gradientLayer
        imageMaskLayer = gradientLayer
        
        // Make themable
        makeThemable()
    }
    
    func theme(didUpdate theme: Theme) {
        topImageView.backgroundColor = theme.background
        backgroundColor = theme.background
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        systemLayoutSizeFitting(size)
    }
    
    override func layoutSubviews() {
        // Restore top image original frame if there is one
        if let topImageOriginalFrame = topImageOriginalFrame,
            let topImageView = topImageView {
            topImageView.frame = topImageOriginalFrame
        }
        
        super.layoutSubviews()
        
        if let topImageView = topImageView {
            // Make sure the original frame is correctly updated
            topImageOriginalFrame = topImageView.frame
            imageMaskLayer?.frame = topImageView.bounds
            
            // Then update the expansion again
            let expansion = headingScrollExpansion
            headingScrollExpansion = expansion
        }
    }
}
