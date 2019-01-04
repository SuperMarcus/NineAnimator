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

class SearchResultViewController: UITableViewController, ContentProviderDelegate {
    var searchText: String? {
        didSet {
            title = searchText
        }
    }
    
    var providerError: Error?
    
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var searchPage: ContentProvider!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 160
        tableView.tableFooterView = UIView()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        searchPage.delegate = nil
        searchPage = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        providerError = nil
        searchPage = NineAnimator.default.user.source.search(keyword: searchText!)
        searchPage.delegate = self
    }
    
    func onError(_ error: Error, from: ContentProvider) {
        self.providerError = error
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tableView.rowHeight = 300
            self.tableView.reloadSections([0], with: .automatic)
        }
    }
    
    func pageIncoming(_ sectionNumber: Int, from page: ContentProvider) {
        DispatchQueue.main.async(execute: tableView.reloadData)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        guard searchPage != nil else { return 0 }
        return searchPage.availablePages + (searchPage.moreAvailable || searchPage.totalPages == 0 ? 1 : 0)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == searchPage.availablePages || searchPage.availablePages == 0 {
            tableView.separatorStyle = .none
            return 1
        }
        tableView.separatorStyle = .singleLine
        return searchPage.animes(on: section).count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let providerError = providerError {
            let cell = tableView.dequeueReusableCell(withIdentifier: "search.notfound", for: indexPath) as! ContentErrorTableViewCell
            cell.error = providerError
            return cell
        }
        
        if searchPage.availablePages == indexPath.section {
            return tableView.dequeueReusableCell(withIdentifier: "search.loading", for: indexPath)
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "search.result", for: indexPath) as? AnimeSearchResultTableViewCell else { fatalError("cell type dequeued is not AnimeSearchResultTableViewCell") }
            cell.animeLink = searchPage.animes(on: indexPath.section)[indexPath.item]
            return cell
        }
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let height = scrollView.frame.size.height
        let contentYoffset = scrollView.contentOffset.y
        let distanceFromBottom = scrollView.contentSize.height - contentYoffset
        if distanceFromBottom < height { searchPage.more() }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        guard let sender = sender as? AnimeSearchResultTableViewCell,
            let anime = sender.animeLink,
            let player = segue.destination as? AnimeViewController
            else { return }
        
        player.setPresenting(anime)
        
        tableView.deselectSelectedRow()
    }
}
