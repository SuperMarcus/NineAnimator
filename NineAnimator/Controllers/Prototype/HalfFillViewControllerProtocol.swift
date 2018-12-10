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

public protocol HalfFillViewControllerProtocol: CustomBarStyleRequiredProtocol {
    var requiredSize: CGFloat { get }
}

public enum HalfFillState{
    case full
    case half
}

extension HalfFillViewControllerProtocol where Self: UIViewController{
//    var shouldStatusBarBeHidden: Bool {
//        if let state = self.halfFillController?.currentState, case .half = state { return true }
//        else { return false }
//    }
    var suggestedStatusBarStyle: UIStatusBarStyle {
        guard let controller = halfFillController else { return .default }
        switch controller.currentState {
        case .half: return .lightContent
        case .full: return .default
        }
    }
    var requiredSize: CGFloat { return 376 }
    var halfFillController: HalfFillPresentationController? {
        return self.presentationController as? HalfFillPresentationController
    }
    
    func animateFill(to state: HalfFillState){
        self.halfFillController?.animate(to: state)
    }
}

public func setupHalfFillView(for vc: UIViewController, from source: UIViewController) -> HalfFillTransitionDelegate{
    let configTransitionDelegate = HalfFillTransitionDelegate(
        presented: source,
        presenting: vc)
    vc.modalPresentationStyle = .custom
    vc.transitioningDelegate = configTransitionDelegate
    return configTransitionDelegate
}
