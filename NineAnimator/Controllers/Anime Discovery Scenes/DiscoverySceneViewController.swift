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

class DiscoverySceneViewController: UITableViewController {
    private var recommendationList = [(RecommendationSource, Recommendation?, Error?)]()
    private var recommendationLoadingTasks = [NineAnimatorAsyncTask]()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.current.preferredStatusBarStyle
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Remove the seperator lines
        tableView.tableFooterView = UIView()
        
        reloadRecommendationList()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: {
            [tableView] _ in
            guard let tableView = tableView else { return }
            tableView.performBatchUpdates({
                tableView.setNeedsLayout()
            }, completion: nil)
        }, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.makeThemable()
    }
}

// MARK: - Table view data source
extension DiscoverySceneViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.numberOfSections
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection _section: Int) -> Int {
        guard let section = Section(rawValue: _section) else {
            Log.error("Unknown section %@ in the Watch Next scene", _section)
            return 0
        }
        
        switch section {
        case .quickActions:
            return 1
        case .recommendations:
            return recommendationList.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(from: indexPath) else {
            Log.error("Unknown section for indexPath %@", indexPath)
            return UITableViewCell()
        }
        
        switch section {
        case .quickActions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "next.actions", for: indexPath) as! QuickActionsTableViewCell
            cell.updateQuickActionsList([
                .init(icon: #imageLiteral(resourceName: "TV Icon"), title: "Continue Watching") { Log.info("continue watching button tapped") },
                .init(icon: #imageLiteral(resourceName: "Library Icon"), title: "Downloaded") { Log.info("offline contents button tapped") }
            ])
            return cell
        case .recommendations:
            let attributes = recommendationList[indexPath.item]
            
            if let recommendation = attributes.1 {
                // return recommendation cell
                return cell(for: recommendation, at: indexPath)
            } else if let error = attributes.2 {
                // return error cell
                return UITableViewCell()
            } else {
                // return loading cell
                let cell = tableView.dequeueReusableCell(withIdentifier: "next.loading", for: indexPath) as! DiscoveryLoadingTableViewCell
                cell.setPresenting(attributes.0)
                return cell
            }
        }
    }
}

// MARK: - Recommendation loading and managing
fileprivate extension DiscoverySceneViewController {
    func cell(for recommendation: Recommendation, at indexPath: IndexPath) -> UITableViewCell {
        switch recommendation.style {
        case .thisWeek:
            let cell = tableView.dequeueReusableCell(withIdentifier: "next.thisWeek", for: indexPath) as! ThisWeekTableViewCell
            cell.setPresenting(recommendation, withSelectionHandler: sharedRecommendingItemCallback)
            return cell
        case .standard:
            let cell = tableView.dequeueReusableCell(withIdentifier: "next.standard", for: indexPath) as! DiscoveryStandardTableViewCell
            cell.setPresenting(recommendation, withSelectionHandler: sharedRecommendingItemCallback)
            return cell
        default: return UITableViewCell()
        }
    }
    
    func reloadRecommendationList() {
        // Abort all previous tasks
        recommendationLoadingTasks = []
        recommendationList = NineAnimator
            .default
            .sortedRecommendationSources()
            .map { ($0, nil, nil) }
        tableView.reloadSections(Section.indexSet(.recommendations), with: .fade)
        
        for (index, (source, _, _)) in recommendationList.enumerated() {
            let task = source
                .generateRecommendations()
                .dispatch(on: .main)
                .error { [weak self] in self?.onRecommendationLoadError(index, source: source, error: $0) }
                .finally { [weak self] in self?.onRecommendationLoad(index, source: source, recommendation: $0) }
            recommendationLoadingTasks.append(task)
        }
    }
    
    func onRecommendationLoad(_ index: Int, source: RecommendationSource, recommendation: Recommendation) {
        recommendationList[index] = (source, recommendation, nil)
        tableView.performBatchUpdates({
            tableView.reloadRows(at: [ Section.recommendations[index] ], with: .fade)
            tableView.setNeedsLayout()
        }, completion: nil)
    }
    
    func onRecommendationLoadError(_ index: Int, source: RecommendationSource, error: Error) {
        recommendationList[index] = (source, nil, error)
        tableView.performBatchUpdates({
            tableView.reloadRows(at: [ Section.recommendations[index] ], with: .fade)
            tableView.setNeedsLayout()
        }, completion: nil)
    }
    
    func didSelectRecommendingItem(_ item: RecommendingItem) {
        RootViewController.open(whenReady: item.link)
    }
    
    var sharedRecommendingItemCallback: (RecommendingItem) -> Void {
        return { [weak self] in self?.didSelectRecommendingItem($0) }
    }
}

// MARK: - Sections definition
fileprivate extension DiscoverySceneViewController {
    enum Section: Int, SectionProtocol, CaseIterable {
        case quickActions
        case recommendations
    }
}

// MARK: - Quick action
extension DiscoverySceneViewController {
    struct QuickAction {
        var icon: UIImage
        var title: String
        var onAction: () -> Void
    }
}
