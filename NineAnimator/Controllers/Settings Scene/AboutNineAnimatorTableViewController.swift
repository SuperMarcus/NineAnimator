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

import SafariServices
import UIKit

class AboutNineAnimatorTableViewController: UITableViewController {
    let urlForIdentifier: [String?: String] = [
        // View GitHub Repository
        "about.viewrepo": "https://github.com/SuperMarcus/NineAnimator",
        // Report issue
        "about.issue": "https://github.com/SuperMarcus/NineAnimator/issues/new",
        // View License
        "about.license": "https://github.com/SuperMarcus/NineAnimator/blob/master/LICENSE",
        "about.credits": "https://nineanimator.marcuszhou.com/docs/credits.html",
        "about.privacy.policy": "https://nineanimator.marcuszhou.com/docs/privacy-policy.html"
    ]
    
    @IBOutlet private weak var versionLabel: UILabel!
    @IBOutlet private weak var buildNumberLabel: UILabel!
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectSelectedRows() }
        
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        if let url = urlForIdentifier[cell.reuseIdentifier] {
            let safariViewController = SFSafariViewController(url: URL(string: url)!)
            present(safariViewController, animated: true)
        } else { // "about.privacy"
            // Manage persisted data (on the previous page)
            navigationController?.popViewController(animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.makeThemable()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.makeThemable()
        configureForTransparentScrollEdge()
        
        // Update version information
        versionLabel.text = NineAnimator.default.version
        buildNumberLabel.text = "\(NineAnimator.default.buildNumber)"
    }
}
