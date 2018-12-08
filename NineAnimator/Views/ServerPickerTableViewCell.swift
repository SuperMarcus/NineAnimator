//
//  ServerPickerTableViewCell.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/6/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import UIKit

protocol ServerPickerSelectionDelegate {
    var server: Anime.ServerIdentifier? { get }
    
    func select(server: Anime.ServerIdentifier)
}

class ServerPickerTableViewCell: UITableViewCell, UIPickerViewDataSource, UIPickerViewDelegate {
    @IBOutlet weak var serverPickerView: UIPickerView!
    
    var _servers = [(identifier: Anime.ServerIdentifier, name: String)]()
    var servers: [Anime.ServerIdentifier: String]? {
        set {
            _servers = newValue!.map { (identifier: $0.key, name: $0.value) }
            if let defaultServer = delegate?.server {
                guard let index = _servers.firstIndex(where: { $0.identifier == defaultServer }) else { return }
                serverPickerView.selectRow(index, inComponent: 0, animated: true)
            }
        }
        get { return nil }
    }
    var delegate: ServerPickerSelectionDelegate? = nil
    
    override func awakeFromNib() {
        super.awakeFromNib()
        serverPickerView.dataSource = self
        serverPickerView.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return _servers.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return _servers[row].name
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        delegate?.select(server: _servers[row].identifier)
    }
}
