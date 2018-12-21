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

class SettingsRootTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBOutlet weak var episodeListingOrderControl: UISegmentedControl!
    
    @IBOutlet weak var viewingHistoryStatsLabel: UILabel!
    
    private var castControllerHandler: Any?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        episodeListingOrderControl.selectedSegmentIndex = NineAnimator.default.user.episodeListingOrder == .reversed ? 0 : 1
        
        updateHistoryStats()
    }
    
    @IBAction func onEpisodeListingOrderChange(_ sender: UISegmentedControl) {
        defer { NineAnimator.default.user.push() }
        
        switch sender.selectedSegmentIndex {
        case 0: NineAnimator.default.user.episodeListingOrder = .reversed
        case 1: NineAnimator.default.user.episodeListingOrder = .ordered
        default: return
        }
    }
    
    @IBAction func onDoneButtonClicked(_ sender: Any) {
        dismiss(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer{ tableView.deselectSelectedRow() }
        
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        
        switch cell.reuseIdentifier {
        case "settings.viewrepo":
            let safariViewController = SFSafariViewController(url: URL(string: "https://github.com/SuperMarcus/NineAnimator")!)
            present(safariViewController, animated: true)
        case "settings.playback.cast.controller":
            self.castControllerHandler = CastController.default.present(from: self)
        case "settings.history.recents":
            NineAnimator.default.user.clearRecents()
            updateHistoryStats()
        case "settings.history.reset":
            let alertView = UIAlertController(title: "Reset local storage", message: "This action is irreversible. All data and preferences will be deleted from your local storage.", preferredStyle: .actionSheet)
            
            if let popover = alertView.popoverPresentationController {
                popover.sourceView = cell.contentView
                popover.permittedArrowDirections = .any
            }
            
            let action = UIAlertAction(title: "Reset", style: .destructive) {
                [weak self] _ in
                NineAnimator.default.user.clearAll()
                self?.updateHistoryStats()
            }
            alertView.addAction(action)
            
            alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alertView, animated: true)
        default: return
        }
    }
    
    private func updateHistoryStats(){
        //To be gramatically correct :D
        let recentAnimesCount = NineAnimator.default.user.recentAnimes.count
        viewingHistoryStatsLabel.text = "\(recentAnimesCount) \(recentAnimesCount > 1 ? "Items" : "Item")"
        
        
    }
}
