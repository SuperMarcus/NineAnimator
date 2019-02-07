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

import UIKit

@IBDesignable
class AnimeRatingView: UIView {
    @IBOutlet private weak var starLabel: UILabel!
    
    @IBOutlet private weak var ratingStringLabel: UILabel!
    
    func update(rating: Float, scale: Float) {
        let normalizedRating = rating / scale
        let filledStartCount = Int(ceil(normalizedRating / 0.2))
        
        let formatter = NumberFormatter()
        formatter.percentSymbol = ""
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        
        var stars = [String](repeating: "★", count: filledStartCount)
        stars += [String](repeating: "☆", count: 5 - filledStartCount)
        
        starLabel.text = stars.joined(separator: " ")
        ratingStringLabel.text = "\(formatter.string(from: NSNumber(value: rating)) ?? "0.0") out of \(formatter.string(from: NSNumber(value: scale)) ?? "0.0")"
    }
    
    func update() {
        starLabel.text = "☆ ☆ ☆ ☆ ☆"
        ratingStringLabel.text = "Unrated"
    }
}
