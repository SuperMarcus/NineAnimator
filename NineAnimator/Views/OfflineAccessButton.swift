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

/// A self-contained view to handle download initiating and monitoring tasks
@IBDesignable
class OfflineAccessButton: UIButton, Themable {
    /// Delegate for this button
    weak var delegate: OfflineAccessButtonDelegate?
    
    private(set) var episodeLink: EpisodeLink?
    private(set) var offlineContent: OfflineEpisodeContent?
    
    @IBInspectable var insetSpace: CGFloat = 6 {
        didSet { updateContent() }
    }
    
    @IBInspectable var strokeWidth: CGFloat = 2 {
        didSet { updateContent() }
    }
    
    @IBInspectable var centerRectWidth: CGFloat = 8 {
        didSet { updateContent() }
    }
    
    @IBInspectable var centerRectCornerRadius: CGFloat = 2 {
        didSet { updateContent() }
    }
    
    private var preservationInitiatedActivityIndicator: UIActivityIndicatorView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        addTarget(self, action: #selector(onTapped(_:)), for: .touchUpInside)
    }
    
    private func commonInit() {
        layer.cornerRadius = 8
        pointerEffect.hover(shadow: true, scale: true)
    }
    
    func setPresenting(_ episodeLink: EpisodeLink, delegate: OfflineAccessButtonDelegate? = nil) {
        let offlineContent = OfflineContentManager
            .shared
            .content(for: episodeLink)
        
        self.episodeLink = episodeLink
        self.offlineContent = offlineContent
        self.delegate = delegate
        
        NotificationCenter.default.removeObserver(self)
        setTitle(nil, for: .normal)
        
        // Add observer to listen to update notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onOfflineAccessStateUpdates(_:)),
            name: .offlineAccessStateDidUpdate,
            object: offlineContent
        )
        
        updateContent()
    }
    
    private func updateContent() {
        func removeActivityIndicator() {
            preservationInitiatedActivityIndicator?.stopAnimating()
            preservationInitiatedActivityIndicator?.removeFromSuperview()
            preservationInitiatedActivityIndicator = nil
        }
        
        guard let content = offlineContent else {
            self.isHidden = true
            return removeActivityIndicator()
        }
        
        switch content.state {
        case .preservationInitiated:
            // Use an empty image and add activity indicator to it
            setImage(UIImage(), for: .normal)
            isHidden = false
            
            // Add the activity indicator if it was not added
            if preservationInitiatedActivityIndicator == nil {
                let newIndicator = UIActivityIndicatorView(style: Theme.current.activityIndicatorStyle)
                newIndicator.frame = bounds
                newIndicator.autoresizingMask = [.flexibleHeight, .flexibleWidth]
                newIndicator.hidesWhenStopped = true
                newIndicator.isUserInteractionEnabled = false
                addSubview(newIndicator)
                preservationInitiatedActivityIndicator = newIndicator
                newIndicator.startAnimating()
            }
        case .error, .ready, .interrupted:
            setImage(#imageLiteral(resourceName: "Cloud Download"), for: .normal)
            removeActivityIndicator()
            isHidden = false
        case .preserved:
            setImage(UIImage(), for: .normal)
            removeActivityIndicator()
            isHidden = true
        case .preserving(let progress):
            let size = bounds.size
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image {
                _ in
                
                let trackPath = UIBezierPath(
                    arcCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    radius: size.width / 2 - insetSpace,
                    startAngle: 0,
                    endAngle: 2 * .pi,
                    clockwise: true
                )
                trackPath.lineWidth = strokeWidth
                Theme.current.secondaryText.withAlphaComponent(0.4).setStroke()
                trackPath.stroke()
                
                let progressPath = UIBezierPath(
                    arcCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    radius: size.width / 2 - insetSpace,
                    startAngle: 3 * .pi / 2,
                    endAngle: (CGFloat(3) * .pi / 2) + (CGFloat(2) * .pi * CGFloat(progress)),
                    clockwise: true
                )
                progressPath.lineWidth = strokeWidth
                Theme.current.tint.setStroke()
                progressPath.stroke()
                
                let centerRect = UIBezierPath(
                    roundedRect: CGRect(
                        x: (size.width / 2) - (centerRectWidth / 2),
                        y: (size.height / 2) - (centerRectWidth / 2),
                        width: centerRectWidth,
                        height: centerRectWidth
                    ),
                    byRoundingCorners: .allCorners,
                    cornerRadii: CGSize(width: centerRectCornerRadius, height: centerRectCornerRadius)
                )
                Theme.current.tint.setFill()
                centerRect.fill()
            }
            setImage(image, for: .normal)
            removeActivityIndicator()
            isHidden = false
        }
    }
    
    // Update UI when received state update notification
    @objc private func onOfflineAccessStateUpdates(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.updateContent() }
    }
    
    @objc private func onTapped(_ sender: Any) {
        guard let episodeLink = episodeLink,
            let content = offlineContent else { return }
        
        switch content.state {
        case .preservationInitiated, .preserving:
            OfflineContentManager.shared.cancelPreservation(content: content)
        case .error, .ready:
            if let delegate = delegate {
                delegate.offlineAccessButton(shouldProceedWithDownload: self, forEpisodeLink: episodeLink) {
                    // The closure does not have a self reference
                    if $0 {
                        OfflineContentManager.shared.initiatePreservation(
                            episodeContent: content,
                            withLoadedAnime: $1
                        )
                    }
                }
            } else {
                // Initiate the preservation directly if no delegate has been set
                OfflineContentManager
                    .shared
                    .initiatePreservation(episodeContent: content)
            }
        case .interrupted:
            // If the download is just interrupted, initiate without consulting the delegate
            OfflineContentManager.shared.initiatePreservation(episodeContent: content)
        case .preserved: break // Do nothing if preserved
        }
    }
    
    func theme(didUpdate theme: Theme) { updateContent() }
}

/// Delegate for offline access button
protocol OfflineAccessButtonDelegate: AnyObject {
    /// Asynchronously check if the download should be proceeded
    /// - Note: There's no need to keep a reference of the source `OfflineAccessButton`. The Calling the `completionHandler` with a result of `true` will start the preservation regardless of the source button.
    func offlineAccessButton(
        shouldProceedWithDownload source: OfflineAccessButton,
        forEpisodeLink episodeLink: EpisodeLink,
        completionHandler: @escaping (Bool, Anime?) -> Void
    )
}
