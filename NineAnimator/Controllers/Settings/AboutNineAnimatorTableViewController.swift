//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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
import SafariServices

class AboutNineAnimatorTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        super.tableView(tableView, didSelectRowAt: indexPath)
        
        defer { tableView.deselectSelectedRow() }
        
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        
        switch cell.reuseIdentifier {
        case "about.viewrepo": //View Github Repository
            let safariViewController = SFSafariViewController(url: URL(string: "https://github.com/SuperMarcus/NineAnimator")!)
            present(safariViewController, animated: true)
        case "about.privacy": //Manage persisted data (on the previous page)
            navigationController?.popViewController(animated: true)
        case "about.issue": //Report issue
            let safariViewController = SFSafariViewController(url: URL(string: "https://github.com/SuperMarcus/NineAnimator/issues/new")!)
            present(safariViewController, animated: true)
        case "about.license": //View License
            let safariViewController = SFSafariViewController(url: URL(string: "https://github.com/SuperMarcus/NineAnimator/blob/master/LICENSE")!)
            present(safariViewController, animated: true)
        case "about.credits":
            let safariViewController = SFSafariViewController(url: URL(string: "https://github.com/SuperMarcus/NineAnimator/blob/master/README.md#credits")!)
            present(safariViewController, animated: true)
        default: return
        }
    }
}
