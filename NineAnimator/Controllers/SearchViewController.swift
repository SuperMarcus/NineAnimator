//
//  SearchViewController.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/8/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit

class SearchViewController: UITableViewController, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate {
    var searchController: UISearchController! = nil
    
    var popularAnimeLinks: [AnimeLink]? = nil {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadSections([0], with: .fade)
            }
        }
    }
    
    var filteredAnimeLinks = [AnimeLink]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.autocapitalizationType = .words
        searchController.searchBar.delegate = self
        
        if #available(iOS 11.0, *) {
            // For iOS 11 and later, place the search bar in the navigation bar.
            navigationItem.searchController = searchController
            
            // Make the search bar always visible.
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            // For iOS 10 and earlier, place the search controller's search bar in the table view's header.
            tableView.tableHeaderView = searchController.searchBar
        }
        
        NineAnimator.default.loadHomePage {
            page, error in
            guard let page = page else {
                debugPrint("Error: \(error!)")
                return
            }
            self.popularAnimeLinks = page.featured + page.latest
        }

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
}

// MARK: Prepare for segues
extension SearchViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        //Have to make sure the search controller is dismissed so we can get our navigation bar back
        searchController.dismiss(animated: false)
        
        if let resultsViewController = segue.destination as? SearchResultViewController {
            resultsViewController.searchText = sender as? String
        }
        
        if let animeViewController = segue.destination as? AnimeViewController,
           let cell = sender as? SimpleAnimeTableViewCell {
            animeViewController.link = cell.animeLink
        }
    }
}

// MARK: - Search events handler
extension SearchViewController {
    func updateSearchResults(for searchController: UISearchController){
        guard let all = popularAnimeLinks else { return }
        
        if let text = searchController.searchBar.text {
            filteredAnimeLinks = all.filter{
                return $0.title.contains(text) || $0.link.absoluteString.contains(text)
            }
        } else { filteredAnimeLinks = all }
        
        tableView.reloadSections([0], with: .fade)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchController.dismiss(animated: true){
            self.performSegue(withIdentifier: "search.result.show", sender: searchBar.text)
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "anime.container.simple", for: indexPath) as? SimpleAnimeTableViewCell else { fatalError("Cell dequeued is not a SimpleAnimeTableViewCell") }
        cell.animeLink = filteredAnimeLinks[indexPath.item]
        return cell
    }
    
    /*
     // Override to support conditional editing of the table view.
     override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the specified item to be editable.
     return true
     }
     */
    
    /*
     // Override to support editing the table view.
     override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
     if editingStyle == .delete {
     // Delete the row from the data source
     tableView.deleteRows(at: [indexPath], with: .fade)
     } else if editingStyle == .insert {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */
    
    /*
     // Override to support rearranging the table view.
     override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
     
     }
     */
    
    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
}
