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

class SearchViewController: UITableViewController, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate {
    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.autocapitalizationType = .words
        searchController.searchBar.delegate = self
        return searchController
    }()
    
    var popularAnimeLinks: [AnimeLink]? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadSections([0], with: .fade)
            }
        }
    }
    
    var filteredAnimeLinks = [AnimeLink]()
    
    var requestTask: NineAnimatorAsyncTask?
    
    var source: Source { return NineAnimator.default.user.source }

    @IBOutlet private weak var selectSiteBarButton: UIBarButtonItem!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NineAnimator.default.user.pull()
        selectSiteBarButton.title = NineAnimator.default.user.source.name
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Make sure we get the navigation bar when clicked on search result
        definesPresentationContext = true
        
        if #available(iOS 11.0, *) {
            // For iOS 11 and later, place the search bar in the navigation bar.
            navigationItem.searchController = searchController
            
            // Make the search bar always visible.
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            // For iOS 10 and earlier, place the search controller's search bar in the table view's header.
            tableView.tableHeaderView = searchController.searchBar
        }
        // Hide table cell separators at empty state
        tableView.tableFooterView = UIView()
        
        requestTask = source.featured {
            [weak self] page, error in
            defer { self?.requestTask = nil }
            guard let page = page else { return Log.error(error) }
            self?.popularAnimeLinks = page.featured + page.latest
        }
    }
}

// MARK: Prepare for segues
extension SearchViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let resultsViewController = segue.destination as? SearchResultViewController {
            resultsViewController.searchText = sender as? String
        }
        
        if let animeViewController = segue.destination as? AnimeViewController,
           let cell = sender as? SimpleAnimeTableViewCell {
            animeViewController.animeLink = cell.animeLink
        }
    }
}

// MARK: - Search events handler
extension SearchViewController {
    func updateSearchResults(for searchController: UISearchController) {
        guard let all = popularAnimeLinks else { return }
        
        if let text = searchController.searchBar.text {
            filteredAnimeLinks = all.filter {
                $0.title.contains(text) || $0.link.absoluteString.contains(text)
            }
        } else { filteredAnimeLinks = all }
        
        tableView.reloadSections([0], with: .fade)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchController.dismiss(animated: true) { [weak self] in
            self?.performSegue(withIdentifier: "search.result.show", sender: searchBar.text)
        }
    }
}

// MARK: - Table view data source
extension SearchViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredAnimeLinks.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "anime.container.simple", for: indexPath) as! SimpleAnimeTableViewCell
        cell.animeLink = filteredAnimeLinks[indexPath.item]
        return cell
    }
}

// MARK: - Source selection
extension SearchViewController {
    @IBAction private func onSelectSourceButtonTapped(_ sender: Any) {
        let currentSource = NineAnimator.default.user.source
        
        let alertView = UIAlertController(title: "Select Site", message: nil, preferredStyle: .actionSheet)
        
        if let popover = alertView.popoverPresentationController {
            popover.barButtonItem = selectSiteBarButton
            popover.permittedArrowDirections = .up
        }
        
        for source in NineAnimator.default.sources {
            let action = UIAlertAction(title: source.name, style: .default) {
                [weak self] _ in
                NineAnimator.default.user.select(source: source)
                
                guard let self = self else { return }
                
                self.selectSiteBarButton.title = source.name
                
                self.requestTask?.cancel()
                self.requestTask = source.featured {
                    [weak self] page, error in
                    defer { self?.requestTask = nil }
                    guard let page = page else { return Log.error(error) }
                    self?.popularAnimeLinks = page.featured + page.latest
                }
            }
            if source.name == currentSource.name {
                action.setValue(true, forKey: "checked")
            }
            alertView.addAction(action)
        }
        
        alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertView, animated: true)
    }
}
