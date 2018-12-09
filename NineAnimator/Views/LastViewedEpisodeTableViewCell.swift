//
//  LastViewedEpisodeTableViewCell.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/9/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit
import Kingfisher

class LastViewedEpisodeTableViewCell: UITableViewCell {
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var backgroundBlurredImageView: UIImageView!
    @IBOutlet weak var progressIndicator: EpisodeAccessoryProcessIndicator!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var episodeLabel: UILabel!
    
    var episodeLink: EpisodeLink? = nil {
        didSet {
            guard let link = episodeLink else { return }
            let coverImageLink = link.parent.image
            coverImageView.kf.setImage(with: coverImageLink)
            backgroundBlurredImageView.kf.setImage(with: coverImageLink)
            progressIndicator.percentage = CGFloat(NineAnimator.default.user.playbackProgress(for: link))
            titleLabel.text = link.parent.title
            episodeLabel.text = "Episode: \(link.name)"
        }
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
