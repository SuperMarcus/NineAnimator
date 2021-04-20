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

import UIKit

/// ViewController for To Watch scene
///
/// ### Updating the Recommendations
///
/// There are several ways to update the recommendations
/// - Fire an .sourceDidUpdateRecommendation with the RecommendationSource as the object.
///   The source will be updated as soon as the notification is received
/// - Call the markSourceAsDirty(_:) method, the source will be updated as soon as the
///   method is invoked
/// - Return true on RecommendationSource.shouldReload(recommendation:). The source will
///   be updated as soon as the To Watch scene is being (re-)presented.
class DiscoverySceneViewController: UITableViewController {
    // Outlets
    @IBOutlet private weak var selectSourceButton: UIBarButtonItem!
    
    private var recommendationList = [(RecommendationSource, Recommendation?, Error?)]()
    private var recommendationLoadingTasks = [ObjectIdentifier: NineAnimatorAsyncTask]()
    private var dirtySources = Set<ObjectIdentifier>()
    private var shouldReloadDirtySourceImmedietly = false
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        Theme.current.preferredStatusBarStyle
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load recommendations
        reloadRecommendationList(shouldInformTableView: false)
        
        // Add recommendation list item
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSourceDidUpdateRecommendation(_:)),
            name: .sourceDidUpdateRecommendation,
            object: nil
        )
        
        // Remove the seperator lines
        tableView.tableFooterView = UIView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Load dirty source as soon as the notification is received
        shouldReloadDirtySourceImmedietly = true
        
        // Reload dirty and errored sources when the view appears
        markDirtySources()
        reloadDirtySources()
        reloadErroredSources()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Disable load dirty source at the moment of notification
        shouldReloadDirtySourceImmedietly = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.makeThemable()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if isBeingPresented {
            coordinator.animate(alongsideTransition: {
                [tableView] _ in
                guard let tableView = tableView else { return }
                tableView.performBatchUpdates({
                    tableView.setNeedsLayout()
                }, completion: nil)
            }, completion: nil)
        }
    }
    
    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                title: "Refresh All Recommendations",
                action: #selector(reloadRecommendationList),
                input: "r", modifierFlags: .command
            )
        ]
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.makeThemable()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = Section(from: indexPath) else {
            return UITableView.automaticDimension
        }
        
        switch section {
        case .quickActions: return UITableView.automaticDimension
        case .recommendations:
            let (source, _, _) = recommendationList[indexPath.item]
            // Hide the table view cell if not presenting
            return source.shouldPresentRecommendation ?
                UITableView.automaticDimension : 0
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let calendarVc = segue.destination as? AnimeScheduleCollectionViewController,
            let calendarSource = sender as? CalendarProvider {
            calendarVc.setPresenting(calendarSource)
        }
    }
}

// MARK: - Delegating actions from cells
extension DiscoverySceneViewController {
    func onViewMoreButtonTapped(_ recommendation: Recommendation, contentProvider: ContentProvider, from: UITableViewCell) {
        // If the contentProvider is a calendar provider, use the calendar view
        if contentProvider is CalendarProvider {
            return performSegue(withIdentifier: "open.schedule", sender: contentProvider)
        }
        
        let storyboard = UIStoryboard(name: "AnimeListing", bundle: Bundle.main)
        guard let listingViewController = storyboard.instantiateInitialViewController() as? ContentListViewController else {
            return Log.error("View controller instantiated from AnimeListing.storyboard is not ContentListViewController")
        }
        
        // Initialize the view controller with content provider
        listingViewController.setPresenting(
            contentProvider: contentProvider
        )
        
        // Present the listing view controller
        if let navigationController = navigationController {
            navigationController.pushViewController(listingViewController, animated: true)
        } else { present(listingViewController, animated: true) }
    }
    
    func didSelect(recommendingItem item: RecommendingItem) {
        RootViewController.open(whenReady: item.link)
    }
}

// MARK: - Table view data source
extension DiscoverySceneViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.numberOfSections
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
            cell.updateQuickActionsList(availableQuickActions) {
                [weak self] action in DispatchQueue.main.async {
                    self?.onQuickActionCompletion(action)
                }
            }
            return cell
        case .recommendations:
            let attributes = recommendationList[indexPath.item]
            
            if !attributes.0.shouldPresentRecommendation {
                // Return empty cell
                return UITableViewCell()
            } else if let recommendation = attributes.1 {
                // return recommendation cell
                return cell(for: recommendation, at: indexPath)
            } else if let error = attributes.2 {
                // return error cell
                let cell = tableView.dequeueReusableCell(withIdentifier: "next.error", for: indexPath) as! DiscoveryErrorTableViewCell
                cell.setPresenting(error, withSource: attributes.0) {
                    [weak self] error, _ in
                    // Show authentication diaglog
                    if let authenticationController = NAAuthenticationViewController.create(
                        from: error,
                        onDismissal: { self?.reloadRecommendationList() }
                    ) { self?.present(authenticationController, animated: true) }
                }
                return cell
            } else {
                // return loading cell
                let cell = tableView.dequeueReusableCell(withIdentifier: "next.loading", for: indexPath) as! DiscoveryLoadingTableViewCell
                cell.setPresenting(attributes.0)
                return cell
            }
        }
    }
}

// MARK: - Quick Action Handling
fileprivate extension DiscoverySceneViewController {
    func onQuickActionCompletion(_ action: QuickAction) {
        markDirtySources()
        reloadDirtySources()
    }
}

// MARK: - Recommendation loading and managing
fileprivate extension DiscoverySceneViewController {
    func cell(for recommendation: Recommendation, at indexPath: IndexPath) -> UITableViewCell {
        switch recommendation.style {
        case .thisWeek:
            let cell = tableView.dequeueReusableCell(withIdentifier: "next.thisWeek", for: indexPath) as! ThisWeekTableViewCell
            cell.setPresenting(recommendation, withDelegate: self)
            return cell
        case .standard:
            let cell = tableView.dequeueReusableCell(withIdentifier: "next.standard", for: indexPath) as! DiscoveryStandardTableViewCell
            cell.setPresenting(recommendation, withDelegate: self)
            return cell
        default: return UITableViewCell()
        }
    }
    
    @objc private func onSourceDidUpdateRecommendation(_ notification: Notification) {
        if let source = notification.object as? RecommendationSource {
            markSourceAsDirty(source)
        }
    }
    
    /// Mark the source as dirty and reload the sources if needed
    private func markSourceAsDirty(_ source: RecommendationSource) {
        let identifier = ObjectIdentifier(source)
        dirtySources.insert(identifier)
        
        // Reload immedietly if currently presenting
        if shouldReloadDirtySourceImmedietly {
            DispatchQueue.main.async { [weak self] in self?.reloadDirtySources() }
        }
    }
    
    /// Reload a particular recommendation source with identifier
    private func reloadRecommendation(for sourceIdentifier: ObjectIdentifier) {
        let enumeratedRecommendationList = recommendationList.enumerated()
        for (index, (source, _, _)) in enumeratedRecommendationList where ObjectIdentifier(source) == sourceIdentifier {
            // Set the source to loading state
            recommendationList[index] = (source, nil, nil)
            tableView.reloadRows(at: [Section.recommendations[index]], with: .fade)
            
            // Create the loading task
            // this will cause any previously created task to abort
            recommendationLoadingTasks[sourceIdentifier] = createTask(for: source, withItemIndex: index)
            _ = dirtySources.remove(sourceIdentifier)
        }
    }
    
    /// Mark the sources that request updates as dirty
    private func markDirtySources() {
        for (source, recommendation, error) in recommendationList where error == nil && source.shouldPresentRecommendation {
            let sourceIdentifier = ObjectIdentifier(source)
            if let recommendation = recommendation {
                if source.shouldReload(recommendation: recommendation) {
                    markSourceAsDirty(source)
                }
            } else if !recommendationLoadingTasks.keys.contains(sourceIdentifier), case .none = error {
                // Mark as dirty if the source hasn't been loaded before
                markSourceAsDirty(source)
            }
        }
    }
    
    /// Reload the recommendations from sources that are marked as dirty
    private func reloadDirtySources() {
        let reloadingSources = dirtySources
        tableView.performBatchUpdates({
            for dirtySourceIdentifier in reloadingSources {
                reloadRecommendation(for: dirtySourceIdentifier)
            }
        }, completion: nil)
    }
    
    /// Reload recommendations from sources that have previously reported errors
    private func reloadErroredSources() {
        tableView.performBatchUpdates({
            let enumeratedRecommendationSourceList = recommendationList.enumerated()
            for (index, (source, _, error)) in enumeratedRecommendationSourceList where error != nil && source.shouldPresentRecommendation {
                // Set to loading state
                recommendationList[index] = (source, nil, nil)
                tableView.reloadRows(at: [ Section.recommendations[index] ], with: .fade)
                
                // Create new loading task
                let identifier = ObjectIdentifier(source)
                let task = createTask(for: source, withItemIndex: index)
                recommendationLoadingTasks[identifier] = task
            }
        }, completion: nil)
    }
    
    /// Reload the entire recommendation list
    @objc func reloadRecommendationList(shouldInformTableView: Bool = true) {
        // Abort all previous tasks
        recommendationLoadingTasks = [:]
        recommendationList = NineAnimator
            .default
            .sortedRecommendationSources()
            .map { ($0, nil, nil) }
        
        if shouldInformTableView {
            tableView.reloadSections(Section.indexSet(.recommendations), with: .fade)
        }
        
        // Only reload recommendations that are marked as presenting
        for (index, (source, _, _)) in recommendationList.enumerated() where source.shouldPresentRecommendation {
            let identifier = ObjectIdentifier(source)
            let task = createTask(for: source, withItemIndex: index)
            recommendationLoadingTasks[identifier] = task
        }
    }
    
    private func createTask(for source: RecommendationSource, withItemIndex index: Int) -> NineAnimatorAsyncTask {
        source
            .generateRecommendations()
            .dispatch(on: .main)
            .error { [weak self] in self?.onRecommendationLoadError(index, source: source, error: $0) }
            .finally { [weak self] in self?.onRecommendationLoad(index, source: source, recommendation: $0) }
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
}

// MARK: - Sections definition
fileprivate extension DiscoverySceneViewController {
    enum Section: Int, SectionProtocol, CaseIterable {
        case quickActions
        case recommendations
    }
}
