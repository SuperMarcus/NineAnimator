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

@IBDesignable
class FrequencyChartView: UIView, Themable {
    /// The distribution data
    var distribution: [Double: Double]? = [
        1: 20, // Some data for storyboard purposes
        2: 343,
        3: 403,
        4: 330,
        5: 637
    ] { didSet { setNeedsDisplay() } }
    
    /// The minimal width of each frequency chart entry
    private var minimalColumnWidth: CGFloat = 8
    
    /// The minimal distance between two column
    private var minimalColumnDistance: CGFloat = 8
    
    /// Maximal column distances until starting to inerpolates data points
    private var maximalColumnDistance: CGFloat = 32
    
    /// The content padding
    private var contentInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    
    /// The height of the bar at zero
    private var zeroHeight: CGFloat = 4
    
    /// The color to fill the bars
    private var fillColor: UIColor = .lightGray
    
    // Font for the labels
    private var labelFont: UIFont = .systemFont(ofSize: 8)
    
    // Height of the labels
    private var labelHeight: CGFloat = 16
    
    // Vertical distance between the bars and the labels
    private var labelBarDistance: CGFloat = 4
    
    private var paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }()
    
    override func draw(_ rect: CGRect) {
        guard let distribution = distribution else { return }
        
        // The actual space that we will be drawing in
        let availableSpace = CGSize(
            width: rect.width - contentInset.left - contentInset.right,
            height: rect.height - contentInset.top - contentInset.bottom
        )
        
        // The space to draw the bars
        let barSpace = CGSize(
            width: availableSpace.width,
            height: availableSpace.height - labelHeight
        )
        
        // And the actual origin
        let drawingOrigin = CGPoint(
            x: rect.origin.x + contentInset.left,
            y: rect.origin.y + contentInset.top
        )
        
        // Make sure there is a size
        guard barSpace.height > 0 && availableSpace.width > minimalColumnWidth else {
            return Log.error("No available space for drawing the frequency chart")
        }
        
        // Calculate the maximal column count
        let maximalColumnCount = Int((availableSpace.width + minimalColumnDistance) / (minimalColumnWidth + minimalColumnDistance))
        let minimalColumnCount = Int((availableSpace.width + maximalColumnDistance) / (minimalColumnWidth + maximalColumnDistance))
        let columnCount = max(min(maximalColumnCount, distribution.count), minimalColumnCount)
        
        // Normalize and scale the data
        let scaledData = expand(scale(distribution, to: columnCount), high: 0.8)
        
        // Calculate the inter-column spacing
        let spacing = ((minimalColumnWidth * CGFloat(scaledData.count)) - availableSpace.width) / (1 - CGFloat(scaledData.count))
        
        guard spacing >= 0 else {
            return Log.error("Calculation returns a negative spacing value between column")
        }
        
        fillColor.setFill()
        fillColor.setStroke()
        var currentX = drawingOrigin.x
        
        // Number formatter
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumSignificantDigits = 3
        
        for (dataValue, dataHeight) in scaledData {
            let height = CGFloat(dataHeight) * (barSpace.height - zeroHeight) + zeroHeight
            let barRect = CGRect(x: currentX, y: drawingOrigin.y + barSpace.height - height, width: minimalColumnWidth, height: height)
            let path = UIBezierPath(roundedRect: barRect, cornerRadius: barRect.width / 2.0)
            path.fill()
            
            // Draw label
            if let labelString = formatter.string(from: NSNumber(value: dataValue)) {
                let labelText = NSAttributedString(
                    string: labelString,
                    attributes: [
                        .font: labelFont,
                        .paragraphStyle: paragraphStyle,
                        .strokeColor: fillColor,
                        .foregroundColor: fillColor
                    ]
                )
                
                let labelRect = CGRect(
                    x: currentX - (spacing / 2),
                    y: drawingOrigin.y + barSpace.height + labelBarDistance,
                    width: minimalColumnWidth + spacing,
                    height: labelHeight - labelBarDistance
                )
                labelText.draw(in: labelRect)
            }
            
            // Adjust current x
            currentX += minimalColumnWidth + spacing
        }
    }
    
    private struct HistogramBlock {
        var range: ClosedRange<Double> {
            upperBound...lowerBound
        }
        
        var value: Double
        var center: Double
        
        var upperBound: Double = -1 {
            didSet {
                if lowerBound == -1 { lowerBound = center * 2 - upperBound }
            }
        }
        
        var lowerBound: Double = -1 {
            didSet {
                if upperBound == -1 { upperBound = center * 2 - lowerBound }
            }
        }
        
        // Calculate area under the closed range
        subscript (_ range: ClosedRange<Double>) -> Double {
            (range.upperBound - range.lowerBound) / (upperBound - lowerBound) * value
        }
        
        init(_ x: Double, height: Double) {
            center = x
            value = height
        }
    }
    
    private func scale(_ porportionDistribution: [Double: Double], to count: Int) -> [(Double, Double)] {
        let distribution = porportionDistribution.sorted { $0.key < $1.key }
        
        // Cannot scale this
        guard distribution.count > 1 else {
            return distribution
        }
        
        // Convert distribution to blocks
        var blocks: [HistogramBlock] = distribution.map {
            HistogramBlock($0.key, height: $0.value)
        }
        
        // Set lower bound and upper bound for blocks
        for index in 0..<distribution.count {
            // If not the first one, then we have a lower bound
            if index > 0 {
                blocks[index].lowerBound = blocks[index - 1].upperBound
            }
            
            // If not the last one, then we have a upper bound
            if index < (distribution.count - 1) {
                let diffX = blocks[index + 1].center - blocks[index].center
                blocks[index].upperBound = blocks[index].center + (diffX / 2)
            }
        }
        
        // Calculate the range
        let min = blocks.first!.lowerBound
        let max = blocks.last!.upperBound
        let stepSize = (max - min) / Double(count)
        
        // Calculate the area under the discrete variable
        func integrate(a: Double, b: Double) -> Double {
            var area = 0.0
            var currentStart = a
            
            for block in blocks where block.lowerBound >= currentStart {
                if block.upperBound < b {
                    area += block[currentStart...block.upperBound]
                    currentStart = block.upperBound
                } else {
                    area += block[currentStart...b]
                    return area
                }
            }
            
            return area
        }
        
        // Return the scaled data
        return normalize((0..<count).map {
            index -> (Double, Double) in
            let begin = min + Double(index) * stepSize
            let end = begin + stepSize
            return ((end + begin) / 2.0, integrate(a: begin, b: end))
        })
    }
    
    // Make the sum of the values 1.0
    private func normalize(_ data: [(Double, Double)]) -> [(Double, Double)] {
        let sum = data.reduce(0.0) { $0 + $1.1 }
        return data.map { ($0.0, $0.1 / sum) }
    }
    
    // Make the highest value to high
    private func expand(_ data: [(Double, Double)], high: Double) -> [(Double, Double)] {
        let maxValue = data.max { $0.1 < $1.1 }!.1
        let ratio = high / maxValue
        return data.map { ($0.0, $0.1 * ratio) }
    }
    
    func theme(didUpdate theme: Theme) {
        self.fillColor = theme.secondaryText
        self.setNeedsDisplay()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.setNeedsDisplay()
    }
}
