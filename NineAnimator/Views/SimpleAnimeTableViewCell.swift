//
//  SimpleAnimeTableViewCell.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/8/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit

class SimpleAnimeTableViewCell: UITableViewCell {
    var animeLink: AnimeLink? = nil {
        didSet{ self.textLabel?.text = animeLink?.title }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
