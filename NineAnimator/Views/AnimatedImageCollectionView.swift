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

private class CollectionSectionView: UIView {
    typealias ImageType = URL
    private var presentingImages = [ImageType]()
    private var imageViewPool = [UIImageView]()
    
    private(set) var overlappingWidth: CGFloat = 0
    private(set) var suggestedCycleInterval: TimeInterval = 5
    private var calculatedCoordinates = [(frame: CGRect, image: ImageType)]()
    
    var spacing: CGFloat = 16
    var minimalImageHeight: CGFloat = 80
    var imageSizeRatio: CGFloat = 0.7
    var evenRowsIndentation: CGFloat = 32
    var individualImageCornerRadius: CGFloat = 6
    var imagePresentationDuration: TimeInterval = 20
    
    func layoutImages() {
        guard !self.presentingImages.isEmpty else {
            overlappingWidth = 0
            return
        }
        
        let bounds = DispatchQueue.main.sync { self.bounds }
        let numberOfRows = ((bounds.height - spacing) / (minimalImageHeight + spacing)).rounded(.down)
        let imageHeight = (bounds.height - spacing) / numberOfRows - spacing
        let imageWidth = imageHeight * imageSizeRatio
        let imageSize = CGSize(width: imageWidth, height: imageHeight)
        
        var presentingImageUrls = self.presentingImages
        
        // Repeat elements to fill the entire viewport
        if CGFloat(presentingImageUrls.count) <
            ((bounds.width / (imageWidth + spacing)).rounded(.up) * numberOfRows) {
            var queue = presentingImageUrls
            while CGFloat(presentingImageUrls.count) <
                ((bounds.width / (imageWidth + spacing)).rounded(.up) * numberOfRows) {
                    let nextInsert = queue.removeFirst()
                    queue.append(nextInsert)
                    presentingImageUrls.append(nextInsert)
            }
        }
        
        // Insert to fill all rows
        if (presentingImageUrls.count % Int(numberOfRows)) != 0 {
            var queue = presentingImageUrls
            while (presentingImageUrls.count % Int(numberOfRows)) != 0 {
                let nextInsert = queue.removeFirst()
                queue.append(nextInsert)
                presentingImageUrls.append(nextInsert)
            }
        }
        
        // Calculate the extended area
        overlappingWidth = CGFloat(presentingImageUrls.count / Int(numberOfRows)) * (imageWidth + spacing) - bounds.width
        suggestedCycleInterval = TimeInterval(presentingImageUrls.count / Int(numberOfRows)) * imagePresentationDuration
        
        // Calculate coordinates
        for (index, image) in presentingImageUrls.enumerated() {
            let rows = Int(numberOfRows)
            let imageFrame = CGRect(
                origin: CGPoint(
                    x: CGFloat(index / rows) * (imageWidth + spacing) + CGFloat(index % rows % 2) * evenRowsIndentation,
                    y: CGFloat(index % rows) * (imageHeight + spacing) + spacing
                ),
                size: imageSize
            )
            calculatedCoordinates.append((
                frame: imageFrame,
                image: image
            ))
        }
    }
    
    func addImageViews() {
        imageViewPool.forEach { $0.removeFromSuperview() }
        imageViewPool = []
        
        for (frame, image) in calculatedCoordinates {
            let imageView = UIImageView(frame: frame)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = individualImageCornerRadius
            prepareImageView(imageView, with: image)
            addSubview(imageView)
            imageViewPool.append(imageView)
        }
    }
    
    private func prepareImageView(_ imageView: UIImageView, with image: ImageType) {
        imageView.kf.setImage(with: image, options: [ .transition(.fade(0.2)) ])
    }
    
    func mirror(_ collectionFrame: CollectionSectionView) {
        calculatedCoordinates = collectionFrame.calculatedCoordinates
        overlappingWidth = collectionFrame.overlappingWidth
        suggestedCycleInterval = collectionFrame.suggestedCycleInterval
    }
    
    func setPresenting(_ imagePool: [ImageType]) {
        presentingImages = imagePool
    }
}

@IBDesignable
class AnimatedImageCollectionView: UIView {
    private var collection = [URL]()
    private var animators = [UIViewPropertyAnimator]()
    private var firstFrame: CollectionSectionView?
    private var secondFrame: CollectionSectionView?
    private var animator: UIViewPropertyAnimator?
    private var previousBounds: CGRect = .zero
    private var startAnimationImmedietly = false
    private var layoutTask: NineAnimatorAsyncTask?
    
    // Inspectables
    
    /// Empty area between the images
    @IBInspectable var spacing: CGFloat = 16
    
    /// Minimal height of images before decreasing the number of rows
    @IBInspectable var minimalImageHeight: CGFloat = 80
    
    /// The width to height ratio of images
    @IBInspectable var imageSizeRatio: CGFloat = 0.7
    
    /// The indentations of even rows
    @IBInspectable var evenRowsIndentation: CGFloat = 32
    
    /// The corner radius of images
    @IBInspectable var individualImageCornerRadius: CGFloat = 6
    
    /// Start the animation when ready
    @IBInspectable var defaultAnimateWhenReady: Bool = false
    
    /// The duration that each images stays on the screen
    ///
    /// Used to determine the `cycleDuration` if `automaticCycleDuration`
    var imagePresentationDuration: TimeInterval = 60
    
    /// The duration that one frame stays on the screen
    ///
    /// Set to AnimatedCollectionView.automaticCycleDuration
    var cycleDuration: TimeInterval = automaticCycleDuration
    
    /// Set cycle duration automatically based on the number of columns
    class var automaticCycleDuration: TimeInterval { return -1 }
    
    /// The maximal allowed displacement of frames without truncating
    var maximalDisplacement: CGFloat {
        guard let firstView = firstFrame else {
            return 0.01
        }
        return firstView.frame.width + firstView.overlappingWidth
    }
    
    /// Adjusting the frame offset of the image views
    private var adjustingContentOffset: CGFloat {
        get {
            guard let firstView = firstFrame else {
                return 0
            }
            let firstFrameOrigin = -firstView.overlappingWidth
            return firstFrameOrigin - firstView.frame.origin.x
        }
        set {
            guard let firstView = firstFrame,
                let secondView = secondFrame else { return }
            var newDisplacement = newValue == maximalDisplacement ? newValue : newValue.truncatingRemainder(dividingBy: maximalDisplacement)
            if newDisplacement < 0 {
                newDisplacement += maximalDisplacement
            }
            
            let firstViewOrigin = -firstView.overlappingWidth
            let secondViewOrigin = firstView.frame.width
            firstView.frame.origin.x = firstViewOrigin - newDisplacement
            secondView.frame.origin.x = secondViewOrigin - newDisplacement
        }
    }
    
    /// Set the content offset of the images
    var contentOffset: CGFloat {
        get { return adjustingContentOffset }
        set {
            var newDisplacement = newValue == maximalDisplacement ? newValue : newValue.truncatingRemainder(dividingBy: maximalDisplacement)
            if newDisplacement < 0 {
                newDisplacement += maximalDisplacement
            }
            animator?.fractionComplete = newDisplacement / maximalDisplacement
        }
    }
    
    func setPresenting(_ collection: [URL]) {
        setPresenting(collection, animateWhenReady: defaultAnimateWhenReady)
    }
    
    /// Set the presenting images
    func setPresenting(_ collection: [URL], animateWhenReady: Bool) {
        self.collection = collection
        
        // Force re-layout images
        self.previousBounds = .zero
        self.startAnimationImmedietly = animateWhenReady
        self.setNeedsLayout()
    }
    
    private func layoutImages() {
        guard !collection.isEmpty else { return }
        let wasAnimating = startAnimationImmedietly || (animator?.isRunning ?? false)
        
        // Remove the animator
        if let animator = self.animator {
            animator.stopAnimation(true)
            self.animator = nil
        }
        
        let previousFirstFrame = firstFrame
        let previousSecondFrame = secondFrame
        
        layoutTask = NineAnimatorPromise.firstly(queue: .main) {
            [weak self] () -> (CollectionSectionView, CollectionSectionView)? in
            guard let self = self else { return nil }
            return (
                CollectionSectionView(frame: self.bounds),
                CollectionSectionView(frame: self.bounds)
            )
        }
        .dispatch(on: .global())
        .then {
            [weak self] firstView, secondView in
            guard let self = self else { return () }
            
            self.configure(frame: firstView)
            firstView.setPresenting(self.collection)
            firstView.layoutImages()
            
            self.configure(frame: secondView)
            secondView.mirror(firstView)
            
            DispatchQueue.main.sync {
                firstView.frame.origin.x = -firstView.overlappingWidth
                secondView.frame.origin.x = firstView.frame.width
                self.addSubview(firstView)
                self.addSubview(secondView)
            }
            
            self.firstFrame = firstView
            self.secondFrame = secondView
            
            // Restart the animation
            if wasAnimating {
                // Reset the start animation flag
                self.startAnimationImmedietly = self.defaultAnimateWhenReady
                self.startAnimation()
            }
            
            return ()
        }
        .dispatch(on: .main)
        .error { e in Log.error(e) }
        .finally {
            [weak self] in
            guard let self = self else { return }
            // Fade out and remove previous frames
            if previousFirstFrame != nil || previousSecondFrame != nil {
                UIView.animate(
                    withDuration: 0.2,
                    animations: {
                        previousFirstFrame?.alpha = 0
                        previousSecondFrame?.alpha = 0
                    },
                    completion: {
                        _ in
                        previousFirstFrame?.removeFromSuperview()
                        previousSecondFrame?.removeFromSuperview()
                    }
                )
            }
            self.firstFrame?.addImageViews()
            self.secondFrame?.addImageViews()
        }
    }
    
    override func layoutSubviews() {
        // Re-layout images if the bounds changed
        if previousBounds != bounds {
            layoutImages()
            previousBounds = bounds
        }
        
        super.layoutSubviews()
    }
    
    /// Setup and start the scrolling animation
    func startAnimation() {
        if animator == nil {
            guard let firstView = firstFrame else {
                return
            }
            animator = UIViewPropertyAnimator.runningPropertyAnimator(
                withDuration: cycleDuration == AnimatedImageCollectionView.automaticCycleDuration ? firstView.suggestedCycleInterval : cycleDuration,
                delay: 0,
                options: [ .repeat, .curveLinear ],
                animations: {
                    [weak self, maximalDisplacement] in
                    self?.adjustingContentOffset = maximalDisplacement
                },
                completion: nil
            )
        }
        animator?.startAnimation()
    }
    
    /// Pause the scrolling animation
    func pauseAnimation() {
        animator?.pauseAnimation()
    }
    
    /// Copy configurations to the frame
    private func configure(frame: CollectionSectionView) {
        // Copy configurations
        frame.spacing = spacing
        frame.minimalImageHeight = minimalImageHeight
        frame.imageSizeRatio = imageSizeRatio
        frame.evenRowsIndentation = evenRowsIndentation
        frame.individualImageCornerRadius = individualImageCornerRadius
        frame.imagePresentationDuration = imagePresentationDuration
    }
}
