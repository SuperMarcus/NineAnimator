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
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: containerView!.bounds.width, height: containerView!.bounds.height))
        
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
    
    private(set) var currentState: HalfFillState = .half
    
    var size: CGFloat {
        guard let vc = self.presentedViewController as? HalfFillViewControllerProtocol else { return 320 }
        return vc.requiredSize
    }
    
    private var insertedView: UIView? = nil
    
    private var haveDefaultTopInsect: Bool {
        return self.presentingViewController.navigationController != nil
    }
    
    override public var frameOfPresentedViewInContainerView: CGRect {
        return CGRect(
            origin: CGPoint(x: 0, y: containerView!.bounds.height - size),
            size: CGSize(
                width: containerView!.bounds.width,
                height: size
            )
        )
    }
    
    private func presentAsFullScreen(){
        guard let presented = self.presentedView else { return }
        guard let container = self.containerView else { return }
        
        var topInsect: CGFloat = 0
        
        if !self.haveDefaultTopInsect{
            topInsect = UIApplication.shared.statusBarFrame.height
            let coveringView = UIView(frame: CGRect(
                origin: CGPoint.zero,
                size: CGSize(width: container.bounds.width, height: topInsect)
            ))
            coveringView.backgroundColor = UIColor(red: 0.976, green: 0.976, blue: 0.976, alpha: 1.0)
            coveringView.alpha = 0
            container.addSubview(coveringView)
            self.insertedView = coveringView
        }
        
        UIView.animate(withDuration: 0.5, animations: {
            presented.frame = CGRect(
                origin: CGPoint(x: 0, y: topInsect),
                size: CGSize(width: container.bounds.width, height: container.bounds.height - topInsect)
            )
            self.insertedView?.alpha = 1.0
        }) { _ in self.updateState(to: .full, with: self.presentingViewController) }
    }
    
    private func presentAsHalfScreen(){
        guard let presented = self.presentedView else { return }
        guard let container = self.containerView else { return }
        
        self.updateState(to: .half, with: self.presentingViewController)
        UIView.animate(withDuration: 0.5, animations: {
            presented.frame = CGRect(
                origin: CGPoint(x: 0, y: container.bounds.height - self.size),
                size: CGSize(width: container.bounds.width, height: self.size)
            )
            self.insertedView?.alpha = 0
        }) { _ in self.clearInsertedView() }
    }
    
    private func clearInsertedView(){
        if let inserted = insertedView {
            inserted.removeFromSuperview()
            insertedView = nil
        }
    }
    
    public func animate(to state: HalfFillState){
        switch state {
        case .half: presentAsHalfScreen()
        case .full: presentAsFullScreen()
        }
    }
    
    override public func presentationTransitionWillBegin() {
        guard let dimmer = self.dimmer else { return }
        guard let container = self.containerView else { return }
        
        dimmer.alpha = 0
        container.addSubview(dimmer)
        dimmer.addSubview(presentedViewController.view)
        
        guard let coordinator = presentingViewController.transitionCoordinator else { return }
        coordinator.animate(alongsideTransition: {
            _ in
            dimmer.alpha = 1
            self.presentingViewController.view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }){ _ in self.updateState(to: .half, with: self.presentingViewController) }
    }
    
    override public func dismissalTransitionWillBegin(){
        guard let coordinator = presentingViewController.transitionCoordinator else { return }
        coordinator.animate(alongsideTransition: {
            _ in
            self.dimmer?.alpha = 0
            self.presentingViewController.view.transform = .identity
        })
        clearInsertedView()
    }
    
    override public func dismissalTransitionDidEnd(_ completed: Bool){
        self.dimmer?.removeFromSuperview()
        self._dimmingView = nil
    }
    
    private func updateState(to state: HalfFillState, with viewController: UIViewController){
        currentState = state
        viewController.setNeedsStatusBarAppearanceUpdate()
    }
}
