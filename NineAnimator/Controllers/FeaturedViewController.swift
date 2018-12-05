//
//  RecentlyUpdatedViewController.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/3/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit

class FeaturedViewController: UITableViewController {
    var featuredAnimePage: FeaturedAnimePage? = nil {
        didSet{
            tableView.reloadSections([0], with: .automatic)
        }
    }
    
    var error: Error?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if case .none = featuredAnimePage {
            NineAnimator.default.loadHomePage {
                page, error in
                DispatchQueue.main.async {
                    self.featuredAnimePage = page
                    self.error = error
                }
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return featuredAnimePage == nil ? 1 : 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if case .none = featuredAnimePage {
            if section == 0 { return 1 }
            return 0
        }
        
        if section == 0 { return featuredAnimePage!.featured.count }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if case .none = featuredAnimePage {
            let loadingCell = tableView.dequeueReusableCell(withIdentifier: "loading", for: indexPath)
            return loadingCell
        }
        
        if indexPath.section == 0 {
            let animeLink = featuredAnimePage!.featured[indexPath.item]
            let animeCell = tableView.dequeueReusableCell(withIdentifier: "anime.featured", for: indexPath) as! FeaturedAnimeTableViewCell
            
            let imageData = try! Data(contentsOf: animeLink.image)
            animeCell.animeTitleLabel.text = animeLink.title
            animeCell.animeImageView.image = UIImage(data: imageData)
            
            return animeCell
        } else {
            fatalError("Unknown section")
        }
    }
}
