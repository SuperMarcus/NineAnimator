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

import Foundation

// swiftlint:disable cyclomatic_complexity
extension String {
    /// Calculate the distance between two strings with Jaro–Winkler
    ///
    /// - parameter t: The target string to be compared to with `self`
    /// - returns: The proximity of the two strings, ranging from `0.0` to `1.0` (with
    ///             `1.0` means the two strings are closer)
    ///
    /// This method is used to match episodes from different sources. When multiple
    /// names are present from one source, the highest proximity value should be
    /// used.
    ///
    /// Authored by [Imizaac](https://rosettacode.org/wiki/User:Imizaac):
    /// [Jaro_distance#Swift](https://rosettacode.org/wiki/Jaro_distance#Swift)
    func proximity(to t: String) -> Double {
        let s = self
        let s_len: Int = s.count
        let t_len: Int = t.count
        
        if s_len == 0 && t_len == 0 {
            return 1.0
        }
        
        if s_len == 0 || t_len == 0 {
            return 0.0
        }
        
        var match_distance: Int = 0
        
        if s_len == 1 && t_len == 1 {
            match_distance = 1
        } else {
            match_distance = ([s_len, t_len].max()!/2) - 1
        }
        
        var s_matches = [Bool]()
        var t_matches = [Bool]()
        
        for _ in 1...s_len {
            s_matches.append(false)
        }
        
        for _ in 1...t_len {
            t_matches.append(false)
        }
        
        var matches: Double = 0.0
        var transpositions: Double = 0.0
        
        for i in 0...s_len-1 {
            let start = [0, (i-match_distance)].max()!
            let end = [(i + match_distance), t_len-1].min()!
            
            if start > end {
                break
            }
            
            for j in start...end {
                if t_matches[j] {
                    continue
                }
                
                if s[String.Index(encodedOffset: i)] != t[String.Index(encodedOffset: j)] {
                    continue
                }
                // We must have a match
                s_matches[i] = true
                t_matches[j] = true
                matches += 1
                break
            }
        }
        
        if matches == 0 {
            return 0.0
        }
        
        var k = 0
        for i in 0...s_len-1 {
            if !s_matches[i] {
                continue
            }
            while !t_matches[k] {
                k += 1
            }
            if s[String.Index(encodedOffset: i)] != t[String.Index(encodedOffset: k)] {
                transpositions += 1
            }
            
            k += 1
        }
        
        let top = (matches / Double(s_len)) + (matches / Double(t_len)) + (matches - (transpositions / 2)) / matches
        return top / 3
    }
}
// swiftlint:enable cyclomatic_complexity
