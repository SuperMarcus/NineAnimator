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

// swiftlint:disable large_tuple
class MinFilledFlowLayoutDelegate: NSObject, UICollectionViewDelegateFlowLayout {
    /// Data source for the collection view
    private weak var dataSource: UICollectionViewDataSource?
    
    /// Minimal size for a given cell
    private var minimalSizes: [CGSize]
    
    /// Bounds for the cached layouts
    private var previousSpace: CGSize
    
    /// Cached layout parameters
    private var cachedLayoutParameters: [Int: (ordinary: CGSize, lastLine: CGSize, lastLineOffset: Int)]
    
    /// If the cells should always fill the line space
    private var alwaysFillLine: Bool
    
    init(dataSource: UICollectionViewDataSource, alwaysFillLine: Bool, minimalSize: CGSize...) {
        // Store parameters
        self.dataSource = dataSource
        self.minimalSizes = minimalSize
        self.previousSpace = .zero
        self.cachedLayoutParameters = [:]
        self.alwaysFillLine = alwaysFillLine
        
        super.init()
    }
    
    func configure(collectionView: UICollectionView) {
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let layout = layout as? UICollectionViewFlowLayout else {
            Log.error("[MinFilledFlowLayoutDelegate] This delegate can only be used with FlowLayout.")
            return .zero
        }
        
        guard dataSource != nil else {
            Log.error("[MinFilledFlowLayoutDelegate] Lost reference to the data source.")
            return .zero
        }
        
        let availableSpace = collectionView.bounds
            .inset(by: collectionView.layoutMargins)
            .inset(by: layout.sectionInset)
            .size
        
        // Clears layout cache when bounds change
        if availableSpace != previousSpace {
            clearLayoutCache()
            previousSpace = availableSpace
        }
        
        // Obtain the calculated layout parameters
        let parameters = cachedLayoutParameters[indexPath.section] ?? calculateLayoutParameters(
            view: collectionView,
            layout: layout,
            section: indexPath.section
        )
        
        return !alwaysFillLine || indexPath.item < parameters.lastLineOffset
            ? parameters.ordinary : parameters.lastLine
    }
    
    /// Forcefully clear the cached layouts for each element
    ///
    /// Layout cache is automatically cleared when the bounds changes
    func clearLayoutCache() {
        cachedLayoutParameters = [:]
    }
    
    /// Recalculate the layout parameters
    private func calculateLayoutParameters(view: UICollectionView, layout: UICollectionViewFlowLayout, section: Int) -> (ordinary: CGSize, lastLine: CGSize, lastLineOffset: Int) {
        guard let dataSource = dataSource else { return (.zero, .zero, 0) }
        
        let availableSpace = view.bounds
            .inset(by: layout.sectionInset)
            .inset(by: view.layoutMargins)
            .size
        let variableParameter: WritableKeyPath<CGSize, CGFloat> =
            layout.scrollDirection == .vertical ? \.width : \.height
        let fixedParameter: WritableKeyPath<CGSize, CGFloat> =
            layout.scrollDirection == .vertical ? \.height : \.width
        
        let totalLength = availableSpace[keyPath: variableParameter]
        let unitMinimal = minimalSize(for: section)[keyPath: variableParameter]
        let availableUnits = dataSource.collectionView(view, numberOfItemsInSection: section)
        let interitemSpace = interitemSpacing(for: view, layout: layout, section: section)
        
        // Calculate unit length
        let ordinalLineUnits = ordinalCellsPerLine(
            minimal: unitMinimal,
            totalLength: totalLength,
            interitemSpace: interitemSpace
        )
        let (_, ordinalLength) = unitParameter(
            minimal: unitMinimal,
            available: .max,
            totalLength: totalLength,
            interitemSpace: interitemSpace
        )
        let (_, lastLineLength) = unitParameter(
            minimal: unitMinimal,
            available: availableUnits % ordinalLineUnits,
            totalLength: totalLength,
            interitemSpace: interitemSpace
        )
        
        // Create three different sizes
        var resultingSize = CGSize()
        resultingSize[keyPath: fixedParameter] = minimalSize(for: section)[keyPath: fixedParameter]
        
        var ordinalSize = resultingSize
        ordinalSize[keyPath: variableParameter] = ordinalLength
        
        var lastLineSize = resultingSize
        lastLineSize[keyPath: variableParameter] = lastLineLength
        
        // Generate and cache result
        let result = (ordinalSize, lastLineSize, availableUnits / ordinalLineUnits * ordinalLineUnits)
        cachedLayoutParameters[section] = result
        return result
    }
    
    /// Calculate the cell size parameters
    private func unitParameter(minimal: CGFloat, available: Int, totalLength: CGFloat, interitemSpace: CGFloat) -> (count: Int, length: CGFloat) {
        let realisticMinimal = (0.00001...totalLength).clamp(value: minimal)
        let count = min(floor((totalLength + interitemSpace) / (realisticMinimal + interitemSpace)), CGFloat(available))
        let length = (totalLength - count * interitemSpace + interitemSpace) / count
        return (Int(count), length)
    }
    
    /// Calculate the number of cells per line assuming the remaining cells are enough to fill the entire space
    private func ordinalCellsPerLine(minimal: CGFloat, totalLength: CGFloat, interitemSpace: CGFloat) -> Int {
        return unitParameter(
            minimal: minimal,
            available: .max,
            totalLength: totalLength,
            interitemSpace: interitemSpace
        ).count
    }
    
    /// Minimal Size
    private func minimalSize(for section: Int) -> CGSize {
        return minimalSizes[min(section, minimalSizes.count - 1)]
    }
    
    private func interitemSpacing(for collectionView: UICollectionView, layout: UICollectionViewFlowLayout, section: Int) -> CGFloat {
        var result = layout.minimumInteritemSpacing
        if let delegate = collectionView.delegate as? UICollectionViewDelegateFlowLayout {
            result = delegate.collectionView?(
                collectionView,
                layout: layout,
                minimumInteritemSpacingForSectionAt: section
            ) ?? result
        }
        return result
    }
}
