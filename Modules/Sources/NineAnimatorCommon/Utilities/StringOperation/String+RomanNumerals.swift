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

import Foundation

public extension String {
    /// A list of unicode character to letters conversion map
    ///
    /// - important: when using, must iterate from top to bottom
    static var romanNumeralMap: [(unicode: String, letters: String)] = [
        ("Ⅿ", "M"),
        ("Ⅾ", "D"),
        ("Ⅽ", "C"),
        ("Ⅼ", "L"),
        ("Ⅻ", "XII"),
        ("Ⅺ", "XI"),
        ("Ⅸ", "IX"),
        ("Ⅹ", "X"),
        ("Ⅷ", "VIII"),
        ("Ⅶ", "VII"),
        ("Ⅵ", "VI"),
        ("Ⅳ", "IV"),
        ("Ⅴ", "V"),
        ("Ⅲ", "III"),
        ("Ⅱ", "II"),
        ("Ⅰ", "I"),
        ("ⅿ", "m"),
        ("ⅾ", "d"),
        ("ⅽ", "c"),
        ("ⅼ", "l"),
        ("ⅻ", "xii"),
        ("ⅺ", "xi"),
        ("ⅸ", "ix"),
        ("ⅹ", "x"),
        ("ⅸ", "ix"),
        ("ⅷ", "viii"),
        ("ⅶ", "vii"),
        ("ⅵ", "vi"),
        ("ⅳ", "iv"),
        ("ⅴ", "v"),
        ("ⅲ", "iii"),
        ("ⅱ", "ii"),
        ("ⅰ", "i")
    ]
    
    var withUnicodeRomanNumerals: String {
        String.romanNumeralMap.reduce(self) { $0.replacingOccurrences(of: $1.letters, with: $1.unicode) }
    }
    
    var withoutUnicodeRomanNumerals: String {
        String.romanNumeralMap.reduce(self) { $0.replacingOccurrences(of: $1.unicode, with: $1.letters) }
    }
}
