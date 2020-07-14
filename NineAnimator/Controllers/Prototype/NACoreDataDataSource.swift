//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2020 Marcus Zhou. All rights reserved.
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

import CoreData
import Foundation
import UIKit

/// A data source used to process managed results controllers
class NACoreDataDataSource<ResultType: NSManagedObject>: NSObject, UITableViewDataSource, UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
    fileprivate(set) var resultsController: NSFetchedResultsController<ResultType>
    fileprivate weak var collectionView: UICollectionView?
    fileprivate weak var tableView: UITableView?
    
    fileprivate var tableViewCellConfigurator: DataSourceCellConfigurator<UITableView, UITableViewCell>?
    fileprivate var collectionViewCellConfigurator: DataSourceCellConfigurator<UICollectionView, UICollectionViewCell>?
    
    typealias DataSourceCellConfigurator<ViewType, CellType> = (_ view: ViewType, _ dataSource: NACoreDataDataSource<ResultType>, _ indexPath: IndexPath, _ object: ResultType) -> CellType
    
    init(_ resultsController: NSFetchedResultsController<ResultType>) {
        self.resultsController = resultsController
        super.init()
        resultsController.delegate = self
    }
    
    @available(*, unavailable)
    override init() {
        fatalError("NACoreDataDataSource should be initialized with a NSFetchedResultsController")
    }
    
    func object(at indexPath: IndexPath) -> ResultType {
        resultsController.object(at: indexPath)
    }
    
    // MARK: - Initializing
    
    func configure(tableView: UITableView, configureCell: @escaping DataSourceCellConfigurator<UITableView, UITableViewCell>) {
        tableView.dataSource = self
        self.tableView = tableView
        self.tableViewCellConfigurator = configureCell
    }
    
    func configure(collectionView: UICollectionView, configureCell: @escaping DataSourceCellConfigurator<UICollectionView, UICollectionViewCell>) {
        collectionView.dataSource = self
        self.collectionView = collectionView
        self.collectionViewCellConfigurator = configureCell
    }
    
    func fetch() {
        do {
            try self.resultsController.performFetch()
        } catch {
            Log.error("[NACoreDataDataSource] Unable to fetch: %@", error)
        }
    }
    
    // MARK: - UITableViewDataSource
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        resultsController.sections?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionInfo = resultsController.sections?[section] else {
            return 0
        }
        
        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellObject = object(at: indexPath)
        
        guard let cellConfigurator = tableViewCellConfigurator else {
            Log.error("[NACoreDataDataSource] Trying to configure a cell, but the cell configurator is not defined.")
            return UITableViewCell()
        }
        
        return cellConfigurator(tableView, self, indexPath, cellObject)
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        resultsController.sections?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let sectionInfo = resultsController.sections?[section] else {
            return 0
        }
        
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellObject = object(at: indexPath)
        
        guard let cellConfigurator = collectionViewCellConfigurator else {
            Log.error("[NACoreDataDataSource] Trying to configure a cell, but the cell configurator is not defined.")
            return UICollectionViewCell()
        }
        
        return cellConfigurator(collectionView, self, indexPath, cellObject)
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView?.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView?.insertRows(at: [ newIndexPath! ], with: .automatic)
            collectionView?.insertItems(at: [ newIndexPath! ])
        case .delete:
            tableView?.deleteRows(at: [ indexPath! ], with: .automatic)
            collectionView?.deleteItems(at: [ indexPath! ])
        case .update:
            tableView?.reloadRows(at: [ indexPath! ], with: .automatic)
            collectionView?.reloadItems(at: [ indexPath! ])
        case .move:
            tableView?.moveRow(at: indexPath!, to: newIndexPath!)
            collectionView?.moveItem(at: indexPath!, to: newIndexPath!)
        @unknown default:
            Log.error("[NACoreDataDataSource] Unknown update of type %@. Flushing data...", type)
            tableView?.reloadData()
            collectionView?.reloadData()
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView?.endUpdates()
    }
}
