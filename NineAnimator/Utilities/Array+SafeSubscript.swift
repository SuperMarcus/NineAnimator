//
//  Array+SafeSubscript.swift
//  NineAnimator
//
//  Created by Uttiya Dutta on 2020-08-07.
//  Copyright © 2020 Marcus Zhou. All rights reserved.
//

import Foundation

extension Collection {

    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return index >= startIndex && index < endIndex ? self[index] : nil
    }
}
