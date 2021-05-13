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

class RecentsSceneCollectionCollectionViewCell: UICollectionViewCell, ContentProviderDelegate, Themable {
    @IBOutlet private weak var collectionTitleLabel: UILabel!
    @IBOutlet private weak var collectionServiceLabel: UILabel!
    @IBOutlet private weak var collectionPreviewView: AnimatedImageCollectionView!
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var headingBackgroundEffeftView: UIVisualEffectView!
    @IBOutlet private weak var statusContainerView: UIView?
    @IBOutlet private weak var statusLabel: UILabel?
    @IBOutlet private weak var statusLoadingIndicator: UIActivityIndicatorView?
    
    private(set) var collection: ListingAnimeCollection?
    
    override var isHighlighted: Bool {
        get { super.isHighlighted }
        set {
            super.isHighlighted = newValue
            
            UIView.animate(withDuration: 0.2) {
                [weak containerView] in
                // Show transform effect when selected
                containerView?.transform = CGAffineTransform(
                    scaleX: newValue ? 0.95 : 1.0,
                    y: newValue ? 0.95 : 1.0
                )
            }
            
            // Continue animation when hightlighted
            if newValue {
                collectionPreviewView.startAnimation()
            } else { collectionPreviewView.pauseAnimation() }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        collectionPreviewView.transform = CGAffineTransform(rotationAngle: -.pi / 7).scaledBy(x: 1.75, y: 1.75)
        makeThemable()
    }
    
    func setPresenting(_ collection: ListingAnimeCollection) {
        // Load collection previews
        self.collection = collection
        self.collection?.delegate = self
        
        if collection.availablePages > 0 {
            pageIncoming(0, from: collection)
        } else { self.collection?.more() }
        
        // Set labels
        collectionTitleLabel.text = collection.title
        collectionServiceLabel.text = collection.parentService.name
        
        // Reset collection preview view
        collectionPreviewView.clearPreview()
        
        // Reset loading indicators
        statusLabel?.text = "Loading Previews"
        statusLoadingIndicator?.isHidden = false
        statusLoadingIndicator?.startAnimating()
    }
    
    func pageIncoming(_ page: Int, from provider: ContentProvider) {
        let references = provider.links(on: page)
        DispatchQueue.main.async {
            [weak collectionPreviewView, weak statusLabel, weak statusLoadingIndicator] in
            let artworks = references.compactMap { $0.artwork }
            collectionPreviewView?.setPresenting(artworks, animateWhenReady: false)
            
            // If no artworks available, show empty collection label
            if artworks.isEmpty {
                statusLabel?.text = "Empty Collection"
            } else { statusLabel?.text = "" }
            
            // Hide the load indicator
            statusLoadingIndicator?.stopAnimating()
            statusLoadingIndicator?.isHidden = true
        }
    }
    
    func willDisplay() {
        // Not animate by default to improve performance
//        collectionPreviewView.startAnimation()
    }
    
    func onError(_ error: Error, from _: ContentProvider) {
        Log.error("An error is received when attempting to load previews for collection: %@", error)
        DispatchQueue.main.async {
            [weak statusLabel, weak statusLoadingIndicator] in
            statusLabel?.text = "No Previews Available"
            statusLoadingIndicator?.stopAnimating()
            statusLoadingIndicator?.isHidden = true
        }
    }
    
    func theme(didUpdate theme: Theme) {
        containerView.backgroundColor = theme.secondaryBackground.withAlphaComponent(0.1)
        containerView.layer.borderColor = theme.secondaryBackground.withAlphaComponent(0.1).cgColor
        containerView.layer.borderWidth = 0.1
        headingBackgroundEffeftView.effect = UIBlurEffect(style: theme.blurStyle)
        backgroundColor = .clear
    }
}
