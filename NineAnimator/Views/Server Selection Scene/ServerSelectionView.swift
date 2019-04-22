//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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

protocol ServerSelectionViewDataSource: AnyObject {
    var sources: [Source] { get }
}

protocol ServerSelectionViewDelegate: AnyObject {
    func serverSelectionView(_ view: ServerSelectionView, didSelect source: Source)
    
    func serverSelectionView(_ view: ServerSelectionView, isSourceSelected source: Source) -> Bool
}

class ServerSelectionView: UITableView, UITableViewDelegate, UITableViewDataSource {
    /// The datasource for this server selection view
    weak var serverDataSource: ServerSelectionViewDataSource?
    
    /// The delegate for this server selection view
    weak var serverSelectionDelegate: ServerSelectionViewDelegate?
    
    // swiftlint:disable weak_delegate
    private var _defaultSelectionDelegate = DefaultSelectionAgent()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _commonInit()
    }
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        _commonInit()
    }
    
    private func _commonInit() {
        // Register the selection cell
        register(
            UINib(nibName: "ServerSelectionCell", bundle: .main),
            forCellReuseIdentifier: "selection.cell"
        )
        allowsMultipleSelection = false
        serverSelectionDelegate = _defaultSelectionDelegate
        serverDataSource = NineAnimator.default
        dataSource = self
        delegate = self
        tableFooterView = UIView()
        
        reloadData()
    }
}

// MARK: - TableView delegate
extension ServerSelectionView {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? ServerSelectionCell else {
            return Log.error("[ServerSelectionView] Selected cell is not an instance of ServerSelectionCell")
        }
        
        guard let selectedSource = cell.representingSource else {
            return Log.error("[ServerSelectionView] Selected cell was not initialized correctly.")
        }
        
        guard let delegate = self.serverSelectionDelegate else {
            return Log.error("[ServerSelectionView] No serverSelectionDelegate was set")
        }
        
        // Call the delegate
        delegate.serverSelectionView(self, didSelect: selectedSource)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? ServerSelectionCell,
            let source = cell.representingSource {
            // Set if the server is selected
            if serverSelectionDelegate?.serverSelectionView(self, isSourceSelected: source) == true {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            } else { tableView.deselectRow(at: indexPath, animated: false) }
        }
        
        cell.makeThemable()
    }
}

// MARK: - TableView data source
extension ServerSelectionView {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return serverDataSource?.sources.count ?? 0
        } else { return 0 }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let sources = serverDataSource?.sources, indexPath.section == 0 {
            let presentingSource = sources[indexPath.item]
            let cell = tableView.dequeueReusableCell(withIdentifier: "selection.cell", for: indexPath) as! ServerSelectionCell
            cell.setPresenting(presentingSource)
            return cell
        }
        
        // Return nil by default
        return UITableViewCell()
    }
}

// Allow NineAnimator as a data source
extension NineAnimator: ServerSelectionViewDataSource { }

private class DefaultSelectionAgent: ServerSelectionViewDelegate {
    func serverSelectionView(_ view: ServerSelectionView, didSelect source: Source) {
        NineAnimator.default.user.select(source: source)
    }
    
    func serverSelectionView(_ view: ServerSelectionView, isSourceSelected source: Source) -> Bool {
        return NineAnimator.default.user.source.name == source.name
    }
}
