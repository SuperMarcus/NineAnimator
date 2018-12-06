//
//  PlayerViewController.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/5/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit
import WebKit

class PlayerViewController: UIViewController {
    
    var link: AnimeLink? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let link = self.link else { return }
        
        NineAnimator.default.anime(with: link){
            anime, error in
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
