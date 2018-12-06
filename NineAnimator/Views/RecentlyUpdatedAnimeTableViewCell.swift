//
//  RecentlyUpdatedAnimeTableViewCell.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/4/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit

class RecentlyUpdatedAnimeTableViewCell: UITableViewCell {
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var blurredCoverImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    var title: String? {
        set { titleLabel.text = newValue ?? "" }
        get { return nil }
    }
    
    var status: String? {
        set { statusLabel.text = newValue ?? "" }
        get { return nil }
    }
    
    var coverImage: URL? {
        set {
            coverImageView.kf.setImage(with: newValue)
            blurredCoverImageView.kf.setImage(with: newValue)
        }
        get { return nil }
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
