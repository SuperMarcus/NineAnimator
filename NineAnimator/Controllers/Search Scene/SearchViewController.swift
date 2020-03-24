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

class SearchViewController: UITableViewController, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate {
    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.autocapitalizationType = .words
        searchController.searchBar.delegate = self
        return searchController
    }()
    
    var source: Source { NineAnimator.default.user.source }
    
    /// List of items which the quick search results are listed from
    private var quickSearchPool = [Item]()
    private var filteredItems = [Item]()
    private var searchingKeywords = ""

    @IBOutlet private weak var selectSiteBarButton: UIBarButtonItem!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NineAnimator.default.user.pull()
        selectSiteBarButton.title = NineAnimator.default.user.source.name
        updateSearchPool()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateSearchResults()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Make sure we get the navigation bar when clicked on search result
        definesPresentationContext = true
        
        // For iOS 11 and later, place the search bar in the navigation bar.
        navigationItem.searchController = searchController
        
        // Make the search bar always visible.
        navigationItem.hidesSearchBarWhenScrolling = false
        
        // Hide table cell separators at empty state
        tableView.tableFooterView = UIView()
        
        // Themes
        tableView.makeThemable()
        searchController.searchBar.makeThemable()
    }
    
    private func updateSearchPool() {
        // Search history
        let searchHistoryItems: [Item] = NineAnimator.default.user.searchHistory.map {
            history in .init(keywords: history, ofType: .history)
        }
        
        // Links from recents
        var recentAnimeList = NineAnimator.default.user.recentAnimes
        
        if recentAnimeList.count > 50 { // Limit to the 50 most recent items
            recentAnimeList = Array(recentAnimeList[0..<50])
        }
        
        let recentAnimeItems: [Item] = Set(recentAnimeList).map {
            recent in .init(.anime(recent), ofType: .recents)
        } .sorted { $0.keywords < $1.keywords }
        
        // Concatenate results to form the items pool
        quickSearchPool = searchHistoryItems + recentAnimeItems
    }
}

// MARK: Prepare for segues
extension SearchViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        // If the segue is pointing towards search results container, show that
        if let resultsViewController = segue.destination as? ContentListViewController,
            !searchingKeywords.isEmpty {
            let contentProvider = NineAnimator.default.user.source.search(keyword: searchingKeywords)
            resultsViewController.setPresenting(contentProvider: contentProvider)
        }
    }
}

// MARK: - Search events handler
extension SearchViewController {
    func updateSearchResults() {
        updateSearchResults(for: searchController)
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        DispatchQueue.main.async {
            let pool = self.quickSearchPool
            
            if let text = self.searchController.searchBar.text, !text.isEmpty {
                self.filteredItems = pool.filter {
                    item in
                    // General matching for all: compare name and type
                    var result = item.link?.name
                        .localizedCaseInsensitiveContains(text) == true
                    result = result || item.keywords
                        .localizedCaseInsensitiveContains(text)
                    result = result || item.type.rawValue
                        .localizedCaseInsensitiveContains(text)
                    
                    // Specialized matchings for each type of links
                    switch item.link {
                    case let .anime(animeLink):
                        result = result || animeLink.link.absoluteString
                            .localizedCaseInsensitiveContains(text)
                        result = result || animeLink.source.name
                            .localizedCaseInsensitiveContains(text)
                    case .episode:
                        break // Not doing anything about EpisodeLink rn
                    case let .listingReference(reference):
                        result = result || reference.parentService.name
                            .localizedCaseInsensitiveContains(text)
                    case .none: break
                    }
                    
                    return result
                }
            } else { self.filteredItems = Array(pool) }
            
            self.tableView.reloadSections([0], with: .fade)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchKeywords = searchBar.text else { return }
        
        searchController.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.performSearch(keywords: searchKeywords)
        }
    }
    
    /// Perform the search with keywords
    func performSearch(keywords: String) {
        searchingKeywords = keywords.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !searchingKeywords.isEmpty else {
            return Log.info("[SearchViewController] Empty query detected. Not performing the search.")
        }
        
        NineAnimator.default.user.enqueueSearchHistory(keywords)
        self.updateSearchPool()
        self.updateSearchResults()
        self.performSegue(withIdentifier: "search.result.show", sender: self)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect rows
        tableView.deselectSelectedRows(animated: true)
        
        if let cell = tableView.cellForRow(at: indexPath) as? SimpleAnimeTableViewCell,
            let item = cell.item {
            if let link = item.link {
                // A little special treatment for AnimeLinks
                if case let .anime(animeLink) = link {
                    // Open the anime link directly if the current source is the link's source
                    if animeLink.source.name == source.name {
                        RootViewController.shared?.open(immedietly: link, in: self)
                    } else {
                        performSearch(keywords: item.keywords)
                    }
                } else {
                    RootViewController.shared?.open(immedietly: link, in: self)
                }
            } else { // For keywords, just search directly
                performSearch(keywords: item.keywords)
            }
        }
    }
}

// MARK: - Table view data source
extension SearchViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "anime.container.simple",
            for: indexPath
        ) as! SimpleAnimeTableViewCell
        cell.setPresenting(filteredItems[indexPath.item])
        cell.makeThemable()
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.makeThemable()
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
        
        for source in NineAnimator.default.sources where source.isEnabled {
            let action = UIAlertAction(title: source.name, style: .default) {
                [weak self] _ in
                NineAnimator.default.user.select(source: source)
                
                guard let self = self else { return }
                
                self.selectSiteBarButton.title = source.name
                self.updateSearchPool()
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

// MARK: - Defs & Helpers
extension SearchViewController {
    /// Definitions of the type of items
    struct ItemType: Hashable {
        static let recents = ItemType(icon: #imageLiteral(resourceName: "Playlist Icon"), rawValue: "Recents")
        static let history = ItemType(icon: #imageLiteral(resourceName: "Clock Icon"), rawValue: "History")
        
        /// Icon of this type presented to the user
        var icon: UIImage
        
        /// An identifying value of this type
        var rawValue: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(rawValue)
        }
    }
    
    /// Representing an item in the quick search results
    struct Item: Hashable {
        /// The link that this item is referenced to
        var link: AnyLink?
        
        /// Keywords of the item
        var keywords: String
        
        /// Type of the item
        var type: ItemType
        
        init(_ link: AnyLink, ofType type: ItemType) {
            self.link = link
            self.type = type
            self.keywords = link.name
        }
        
        init(keywords: String, ofType type: ItemType) {
            self.keywords = keywords
            self.type = type
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(link)
            hasher.combine(type)
        }
    }
}
