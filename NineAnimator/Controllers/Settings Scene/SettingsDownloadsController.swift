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

import Kingfisher
import UIKit

class SettingsDownloadsController: UITableViewController {
    @IBOutlet private weak var storageUsageGraphCell: SettingsStorageGraphCell!
    @IBOutlet private weak var storageUsageTipCell: SettingsStorageTipCell!
    @IBOutlet private weak var downloadsUsageLabel: UILabel!
    @IBOutlet private weak var cachedImageUsageLabel: UILabel!
    @IBOutlet private weak var autoRetrySwitch: UISwitch!
    @IBOutlet private weak var preventPurgingSwitch: UISwitch!
    @IBOutlet private weak var sendNotificationsSwitch: UISwitch!
    
    private var usageLoadingTask: NineAnimatorAsyncTask?
    private var statistics: UsageStatistics?
    private var criticalStorageThreshold: Int {
        3_221_225_472 // 3 Gigabytes
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureForTransparentScrollEdge()
        updateUIComponents()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.makeThemable()
        self.reloadUsage()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectSelectedRows() }
        
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        func askForConfirmation(title: String,
                                message: String,
                                continueActionName: String,
                                proceed: @escaping () -> Void) {
            let alertView = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            configureStyleOverride(alertView)
            
            if let popover = alertView.popoverPresentationController {
                popover.sourceView = cell.contentView
                popover.permittedArrowDirections = .any
            }
            
            let action = UIAlertAction(title: continueActionName, style: .destructive) { _ in proceed() }
            alertView.addAction(action)
            
            alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alertView, animated: true)
        }
        
        switch cell.reuseIdentifier {
        case "storage.images.remove":
            Kingfisher.ImageCache.default.clearDiskCache {
                [weak self] in self?.reloadUsage()
            }
        case "storage.downloads.remove":
            askForConfirmation(
                title: "Remove All Downloads",
                message: "You won't be able to recover any of the downloaded episodes unless you redownload them.",
                continueActionName: "Remove Downloads"
            ) {
                OfflineContentManager.shared.deleteAll()
                self.reloadUsage()
            }
        default: break
        }
    }
    
    fileprivate func reloadUsage() {
        usageLoadingTask = fetchStorageUsage()
            .dispatch(on: .main)
            .error { Log.error("[SettingsDownloadsController] Error updating statistics: %@", $0) }
            .finally {
                [unowned self] statistics in
                self.statistics = statistics
                self.updateUIComponents()
            }
    }
    
    fileprivate func updateUIComponents() {
        if let statistics = statistics {
            let availableSpaceDescription = String(
                format: "%@ Available",
                ByteCountFormatter.string(
                    fromByteCount: Int64(statistics.availableSpace),
                    countStyle: .file
                )
            )
            
            let downloadsPct = Double(statistics.downloadedEpisodeSpace)
                / Double(statistics.totalSpace)
            let imageCachePct = Double(statistics.imageCacheSpace)
                / Double(statistics.totalSpace)
            
            let totalAccountedPct = downloadsPct + imageCachePct + 0.0001
            let otherPct = (1.0 - Double(statistics.availableSpace)
                / Double(statistics.totalSpace)) - totalAccountedPct
            
            // Scale NineAnimator's usage to 80% of the bar
            let componentStretchFactor = 0.8 / totalAccountedPct
            let componentCompressFactor = 0.2 / (1 - totalAccountedPct)
            
            storageUsageGraphCell.setPresenting(
                [
                    .init(
                        title: "Episodes",
                        percentage: downloadsPct * componentStretchFactor,
                        color: .systemRed
                    ),
                    .init(
                        title: "Images",
                        percentage: imageCachePct * componentStretchFactor,
                        color: .systemGreen
                    ),
                    .init(
                        title: "Other",
                        percentage: otherPct * componentCompressFactor,
                        color: .lightGray
                    )
                ],
                usage: availableSpaceDescription
            )
            
            downloadsUsageLabel.text = ByteCountFormatter.string(
                fromByteCount: Int64(statistics.downloadedEpisodeSpace),
                countStyle: .file
            )
            
            cachedImageUsageLabel.text = ByteCountFormatter.string(
                fromByteCount: Int64(statistics.imageCacheSpace),
                countStyle: .file
            )
            
            if statistics.availableSpace > criticalStorageThreshold {
                storageUsageTipCell.updateMessages(
                    .normal,
                    title: "You have enough storage left.",
                    message: "The system may delete downloaded contents when disk space is low."
                )
            } else {
                storageUsageTipCell.updateMessages(
                    .saturated,
                    title: "Your storage is almost full.",
                    message: "The system may delete downloaded contents when disk space is low."
                )
            }
        } else { // Set every compoennt to updating state
            storageUsageGraphCell.setPresentingUpdateState()
            storageUsageTipCell.updateMessages(
                .unknown,
                title: "Calculating Storage Usage...",
                message: "The system may delete downloaded contents when disk space is low."
            )
            [ downloadsUsageLabel, cachedImageUsageLabel ].forEach {
                $0.text = "Updating..."
            }
        }
        
        // Update preferences states
        autoRetrySwitch.setOn(
            NineAnimator.default.user.autoRestartInterruptedDownloads,
            animated: true
        )
        preventPurgingSwitch.setOn(
            NineAnimator.default.user.preventAVAssetPurge,
            animated: true
        )
        sendNotificationsSwitch.setOn(
            NineAnimator.default.user.sendDownloadsNotifications,
            animated: true
        )
    }
    
    @IBAction private func onAutoRetrySwitchDidChange(_ sender: UISwitch) {
        NineAnimator.default.user.autoRestartInterruptedDownloads = sender.isOn
    }
    
    @IBAction private func onPreventPurgeSwitchDidChange(_ sender: UISwitch) {
        NineAnimator.default.user.preventAVAssetPurge = sender.isOn
        OfflineContentManager.shared.updateStoragePolicies()
    }
    
    @IBAction private func onSendNotificationSwitchDidChange(_ sender: UISwitch) {
        NineAnimator.default.user.sendDownloadsNotifications = sender.isOn
        
        if sender.isOn { // Request notification permissions
            UserNotificationManager.default.requestNotificationPermissions()
        }
    }
}

// MARK: - Calculate Usage
extension SettingsDownloadsController {
    struct UsageStatistics {
        var availableSpace: Int
        var totalSpace: Int
        var downloadedEpisodeSpace: Int
        var downloadedEpisodes: Int
        var imageCacheSpace: Int
    }
    
    fileprivate func fetchStorageUsage() -> NineAnimatorPromise<UsageStatistics> {
        OfflineContentManager.shared.fetchDownloadStorageStatistics().thenPromise {
            [unowned self] stats in self.fetchImageCacheUsage().then {
                (stats, $0)
            }
        }.then {
            downloadStorageStatistics, imageCacheSize in
            let fs = FileManager.default
            let homeDirectoryAttributes = try fs.attributesOfFileSystem(
                forPath: NSHomeDirectory()
            )
            let totalSpace = homeDirectoryAttributes[.systemSize, typedDefault: 1]
            let freeSpace = homeDirectoryAttributes[.systemFreeSize, typedDefault: 1]
            
            return UsageStatistics(
                availableSpace: freeSpace,
                totalSpace: totalSpace,
                downloadedEpisodeSpace: downloadStorageStatistics.totalBytes,
                downloadedEpisodes: downloadStorageStatistics.numberOfAssets,
                imageCacheSpace: imageCacheSize
            )
        }
    }
    
    fileprivate func fetchImageCacheUsage() -> NineAnimatorPromise<Int> {
        let cache = Kingfisher.ImageCache.default
        let storagePath = cache.diskStorage.directoryURL
        return FileManager.default.sizeOfItem(atUrl: storagePath)
    }
}
