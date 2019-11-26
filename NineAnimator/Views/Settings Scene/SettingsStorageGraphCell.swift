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

class SettingsStorageGraphCell: UITableViewCell, Themable {
    @IBOutlet private weak var usageLabel: UILabel!
    @IBOutlet private weak var graphView: PortionBarView!
    @IBOutlet private weak var graphLabelsContainer: PortionBarLabels!
    
    private var segments = [Segment]()
    
    struct Segment {
        var title: String
        var percentage: Double
        var color: UIColor
    }
    
    func setPresentingUpdateState() {
        usageLabel.text = "Calculating Usage..."
        segments = []
        pushSegments()
    }
    
    func setPresenting(_ segments: [Segment], usage: String) {
        self.segments = segments
        self.usageLabel.text = usage
        self.pushSegments()
    }
    
    private func pushSegments() {
        if segments.isEmpty {
            graphView.segments = []
            graphLabelsContainer.labels = [
                ("Calculating", graphView.remainingSpaceColor)
            ]
        } else {
            graphView.segments = segments.map {
                ($0.percentage, $0.color)
            }
            graphLabelsContainer.labels = segments.map {
                ($0.title, $0.color)
            }
        }
        
        // Update views
        graphView.setNeedsDisplay()
        graphLabelsContainer.setNeedsDisplay()
    }
    
    func theme(didUpdate theme: Theme) {
        graphView?.setNeedsDisplay()
        graphLabelsContainer?.setNeedsDisplay()
        backgroundColor = theme.background
    }
}
