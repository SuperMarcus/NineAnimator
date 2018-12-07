//
//  AnimeDescriptionTableViewCell.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/6/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit
import Kingfisher

class AnimeDescriptionTableViewCell: UITableViewCell {
    @IBOutlet weak var backgroundBlurredImageView: UIImageView!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var descriptionText: UITextView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    var animeDescription: String? {
        set {
            guard let newValue = newValue else {
                descriptionText.isHidden = true
                loadingIndicator.isHidden = false
                loadingIndicator.startAnimating()
                return
            }
            
            UIView.transition(with: loadingIndicator, duration: 0.3, options: .curveEaseOut, animations: {
                self.descriptionText.text = newValue
                self.descriptionText.isHidden = false
                self.loadingIndicator.stopAnimating()
                self.loadingIndicator.isHidden = true
            })
        }
        get { return nil }
    }
    
    var link: AnimeLink? {
        didSet {
            guard let link = link else { return }
            backgroundBlurredImageView.kf.setImage(with: link.image)
            coverImageView.kf.setImage(with: link.image)
        }
    }
    
    var animeViewController: AnimeViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
