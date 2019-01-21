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

import Kingfisher
import UIKit

class FeaturedViewController: UITableViewController {
    var featuredAnimePage: FeaturedContainer? {
        didSet {
            UIView.transition(
                with: tableView,
                duration: 0.35,
                options: .transitionCrossDissolve,
                animations: tableView.reloadData
            )
        }
    }
    
    @IBOutlet private weak var sourceSelectionButton: UIBarButtonItem!
    
    private lazy var refresher: UIRefreshControl = {
        let refresher = UIRefreshControl()
        refresher.addTarget(self, action: #selector(onRefreshRequested), for: .valueChanged)
        return refresher
    }()
    
    var error: Error?
    
    var requestTask: NineAnimatorAsyncTask? {
        didSet { sourceSelectionButton.isEnabled = requestTask == nil }
    }
    
    var loadedSource: Source?
    
    var source: Source { return NineAnimator.default.user.source }
    
    func reload() {
        featuredAnimePage = nil
        refresher.beginRefreshing()
        tableView.reloadData()
        requestTask = source.featured {
            [source] page, error in
            DispatchQueue.main.async { [weak self] in
                defer {
                    self?.requestTask = nil
                    self?.refresher.endRefreshing()
                }
                self?.error = error
                self?.loadedSource = source
                self?.sourceSelectionButton.title = source.name
                self?.featuredAnimePage = page
            }
        }
    }
    
    @objc func onRefreshRequested() { reload() }
    
    @IBAction private func onSourceSelectionButtonPressed(_ sender: Any) {
        let alertView = UIAlertController(title: "Select Site", message: nil, preferredStyle: .actionSheet)
        
        if let popover = alertView.popoverPresentationController {
            popover.barButtonItem = sourceSelectionButton
            popover.permittedArrowDirections = .up
        }
        
        for source in NineAnimator.default.sources {
            let action = UIAlertAction(title: source.name, style: .default) {
                [weak self] _ in
                NineAnimator.default.user.select(source: source)
                self?.reload()
            }
            if source.name == loadedSource?.name {
                action.setValue(true, forKey: "checked")
            }
            alertView.addAction(action)
        }
        
        alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertView, animated: true)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return featuredAnimePage == nil ? 1 : 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let featuredAnimePage = featuredAnimePage else { return error == nil ? 0 : 1 }
        
        switch section {
        case 0: return featuredAnimePage.featured.count
        case 1: return featuredAnimePage.latest.count
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let featuredAnimePage = featuredAnimePage else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "anime.unavailable", for: indexPath)
            if let cell = cell as? UnavailableTableViewCell { cell.error = error }
            return cell
        }
        switch indexPath.section {
        case 0:
            let animeLink = featuredAnimePage.featured[indexPath.item]
            let animeCell = tableView.dequeueReusableCell(withIdentifier: "anime.featured", for: indexPath) as! FeaturedAnimeTableViewCell
            animeCell.setAnime(animeLink)
            return animeCell
        case 1:
            let animeLink = featuredAnimePage.latest[indexPath.item]
            let animeCell = tableView.dequeueReusableCell(withIdentifier: "anime.updated", for: indexPath) as! RecentlyUpdatedAnimeTableViewCell
            
            animeCell.title = animeLink.title
            animeCell.coverImage = animeLink.image
            
            return animeCell
        default:
            fatalError("Unknown section")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        var pools = [
            featuredAnimePage?.featured,
            featuredAnimePage?.latest
        ]
        guard let playerViewController = segue.destination as? AnimeViewController,
            let cell = sender as? UITableViewCell,
            let selected = tableView.indexPath(for: cell),
            let animeLink = pools[selected.section]?[selected.item]
            else { return }
        playerViewController.setPresenting(anime: animeLink)
    }
}

// MARK: - ViewController lifecycle
extension FeaturedViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NineAnimator.default.user.pull()
        if loadedSource?.name != source.name {
            reload()
        }
    }
    
    // turn off highlighting effect when users can't see this happening
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.deselectSelectedRow()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.refreshControl = refresher
        userActivity = Continuity.activityForResumeLastAnime()
    }
}

extension FeaturedViewController {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        guard let visibleRows = tableView.indexPathsForVisibleRows, !visibleRows.isEmpty else { return }
        let topCellPath = visibleRows.count > 1 ? visibleRows[1] : visibleRows[0]
        self.tableView.reloadSections(.init(0..<self.tableView.numberOfSections), with: .automatic)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.tableView.scrollToRow(at: topCellPath, at: .top, animated: true)
        }
    }
}
