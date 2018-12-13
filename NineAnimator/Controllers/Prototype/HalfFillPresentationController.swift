//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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

public class HalfFillPresentationController: UIPresentationController {
    private var _dimmingView: UIView?
    
    private var dimmer: UIView? {
        if let dimmedView = _dimmingView {
            return dimmedView
        }
        
        let view = UIView(frame: containerView!.bounds)
        
        // Blur Effect
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        view.addSubview(blurEffectView)
        
        // Vibrancy Effect
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        let vibrancyEffectView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyEffectView.frame = view.bounds
        
        // Add the vibrancy view to the blur view
        blurEffectView.contentView.addSubview(vibrancyEffectView)
        
        _dimmingView = view
        
        return view
    }
    
    public var viewController: HalfFillViewControllerProtocol {
        return super.presentedViewController as! HalfFillViewControllerProtocol
    }
    
    public func layoutBackgroundView(with size: CGSize) {
        var view: UIView? = _dimmingView
        while view != nil {
            view?.frame.size = size
            view = view?.subviews.first
        }
    }
    
    private func presentAsFullScreen() {
        guard let presented = presentedView,
            let container = containerView
            else { return }
        
        presented.frame = container.bounds
    }
    
    override public func presentationTransitionWillBegin() {
        guard let dimmer = dimmer,
            let container = containerView
            else { return }
        
        dimmer.alpha = 0
        container.addSubview(dimmer)
        dimmer.addSubview(presentedViewController.view)
        
        guard let coordinator = presentingViewController.transitionCoordinator else { return }
        coordinator.animate(alongsideTransition: { _ in
            dimmer.alpha = 1
            self.presentingViewController.view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in self.updateState(viewController: self.presentingViewController) }
    }
    
    override public func dismissalTransitionWillBegin() {
        guard let coordinator = presentingViewController.transitionCoordinator else { return }
        coordinator.animate(alongsideTransition: { _ in
            self.dimmer?.alpha = 0
            self.presentingViewController.view.transform = .identity
        })
    }
    
    override public func dismissalTransitionDidEnd(_ completed: Bool) {
        dimmer?.removeFromSuperview()
        _dimmingView = nil
    }
    
    private func updateState(viewController: UIViewController) {
        viewController.setNeedsStatusBarAppearanceUpdate()
    }
}
