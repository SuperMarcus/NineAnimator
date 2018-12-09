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

class RecentlyViewedTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
}

extension RecentlyViewedTableViewController {
    @IBAction func onClearButtonPressed(_ sender: Any) {
        NineAnimator.default.user.clear()
        tableView.reloadSections([0, 1], with: .automatic)
    }
}

// MARK: - Table view data source
extension RecentlyViewedTableViewController{
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return NineAnimator.default.user.lastEpisode == nil ? 0 : 1
        case 1: return NineAnimator.default.user.recentAnimes.count
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return traitCollection.verticalSizeClass == .compact
            || traitCollection.horizontalSizeClass == .compact
            ? 160 : 200
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "recent.last", for: indexPath) as? LastViewedEpisodeTableViewCell else { fatalError() }
            cell.episodeLink = NineAnimator.default.user.lastEpisode
            return cell
        case 1:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "recent.anime", for: indexPath) as? RecentlyWatchedAnimeTableViewCell else { fatalError() }
            let animes = NineAnimator.default.user.recentAnimes
            let anime = animes[animes.count - indexPath.item - 1]
            cell.animeLink = anime
            return cell
        default: fatalError("unimplemented section (\(indexPath.section))")
        }
    }
}

// MARK: - Segue preparation
extension RecentlyViewedTableViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let player = segue.destination as? AnimeViewController else { return }
        
        if let animeCell = sender as? RecentlyWatchedAnimeTableViewCell {
            player.animeLink = animeCell.animeLink
        }
        
        if let episodeCell = sender as? LastViewedEpisodeTableViewCell {
            player.episodeLink = episodeCell.episodeLink
        }
    }
}
