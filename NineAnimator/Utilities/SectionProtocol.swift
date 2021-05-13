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

/// A helper protocol for identifying sections of a table view or collection view
///
/// Also implements `RawRepresentable<Int>`, `CaseIterable` to get the complete set
/// of features
protocol SectionProtocol {
    var rawValue: Int { get }
}

extension SectionProtocol {
    subscript(_ item: Int) -> IndexPath {
        IndexPath(item: item, section: self.rawValue)
    }
    
    func `is`(_ integerSectionNumber: Int) -> Bool {
        rawValue == integerSectionNumber
    }
    
    func `is`(_ anotherSection: Self) -> Bool {
        anotherSection.rawValue == rawValue
    }
    
    func contains(_ indexPath: IndexPath) -> Bool {
        self.is(indexPath.section)
    }
    
    static func indexSet(_ sections: [Self]) -> IndexSet {
        IndexSet(sections.map { $0.rawValue })
    }
    
    static func indexSet(_ sections: Self...) -> IndexSet {
        IndexSet(sections.map { $0.rawValue })
    }
}

extension SectionProtocol where Self: CaseIterable {
    static var allSections: [Self] {
        Self.allCases.map { $0 }
    }
    
    static var numberOfSections: Int {
        Self.allCases.count
    }
}

extension SectionProtocol where Self: RawRepresentable, Self.RawValue == Int {
    init?(from indexPath: IndexPath) {
        self.init(rawValue: indexPath.section)
    }
}
