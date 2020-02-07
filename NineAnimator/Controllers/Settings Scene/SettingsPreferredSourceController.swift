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

import UIKit

class SettingsPreferredSourceController: UITableViewController {
    private var availableSources = [ListingService]()
    
    override func viewDidLoad() {
        reloadAvailableSources(shouldNotifyTableView: false)
        super.viewDidLoad()
        configureForTransparentScrollEdge()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.makeThemable()
        self.tableView.tableFooterView = UIView()
        
        // Mark currently selected item
        if let selectedService = NineAnimator.default.user.preferredAnimeInformationService,
            let selectedItemIndex = availableSources.firstIndex(where: {
                $0.name == selectedService.name
            }) {
            self.tableView.selectRow(
                at: IndexPath(item: selectedItemIndex, section: 0),
                animated: true,
                scrollPosition: .middle
            )
        } else {
            // Select the last "Automatic" option
            self.tableView.selectRow(
                at: IndexPath(item: availableSources.count, section: 0),
                animated: true,
                scrollPosition: .middle
            )
        }
    }
    
    private func reloadAvailableSources(shouldNotifyTableView: Bool = true) {
        availableSources = NineAnimator.default.trackingServices.filter {
            $0.isCapableOfListingAnimeInformation
        }
        
        if shouldNotifyTableView {
            tableView.reloadSections([0], with: .fade)
        }
    }

    // MARK: - Data Source

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int { availableSources.count + 1 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "source",
            for: indexPath
        ) as! SettingsPreferredSourceCell
        cell.setPresenting(
            indexPath.item >= availableSources.count
            ? nil : availableSources[indexPath.item]
        )
        return cell
    }
    
    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? { "Anime List" }
    
    override func tableView(
        _ tableView: UITableView,
        titleForFooterInSection section: Int
    ) -> String? { "Prefer information from the selected anime list service." }
    
    // MARK: - Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedService = indexPath.item >= availableSources.count
            ? nil : availableSources[indexPath.item]
        NineAnimator.default.user.preferredAnimeInformationService = selectedService
        performSegue(withIdentifier: "config.done", sender: self)
    }
}
