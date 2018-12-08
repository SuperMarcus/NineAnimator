//
//  SearchResultViewController.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/8/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit

class SearchResultViewController: UITableViewController, SearchPageDelegate {
    var searchText: String? = nil {
        didSet {
            self.title = searchText
        }
    }
    
    private var searchPage: SearchPage!

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.searchPage.delegate = nil
        self.searchPage = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.searchPage = NineAnimator.default.search(searchText!)
        self.searchPage.delegate = self
    }
    
    func noResult(in: SearchPage) {
        
    }
    
    func pageIncoming(_ sectionNumber: Int, in page: SearchPage) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return searchPage.availablePages + (searchPage.moreAvailable ? 1 : 0)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == searchPage.availablePages { return 1 }
        return searchPage.animes(on: section).count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if searchPage.availablePages == indexPath.section {
            let cell = tableView.dequeueReusableCell(withIdentifier: "search.loading", for: indexPath)
            return cell
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
            let anime = sender.animeLink else { return }
        
        guard let player = segue.destination as? AnimeViewController else { return }
        
        player.link = anime
        
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}
