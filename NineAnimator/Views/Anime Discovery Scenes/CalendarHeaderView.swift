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

class CalendarHeaderView: UICollectionReusableView {
    @IBOutlet private var dateLabel: UILabel!
    @IBOutlet private var dayOfWeekLabel: UILabel!
    
    private(set) var representingDay: AnimeScheduleCollectionViewController.ScheduledDay?
    private(set) weak var delegate: AnimeScheduleCollectionViewController?
    
    func setPresenting(_ day: AnimeScheduleCollectionViewController.ScheduledDay, withDelegate delegate: AnimeScheduleCollectionViewController) {
        self.representingDay = day
        self.delegate = delegate
        
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        
        // Format day of week component
        formatter.dateFormat = "EEEE"
        dayOfWeekLabel.text = formatter.string(from: day.referenceDate)
        
        // Format date
        formatter.dateFormat = "MMM d, yyyy"
        dateLabel.text = formatter.string(from: day.referenceDate)
    }
}
