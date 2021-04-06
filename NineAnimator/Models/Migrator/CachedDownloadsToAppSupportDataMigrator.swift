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

import Foundation

// Migrates downloaded episodes from the cache directory to the new application support directory
class CachedDownloadsToAppSupportDataMigrator: ModelMigrator {
    weak var delegate: ModelMigratorDelegate?
    
    private var currentProgress: ModelMigrationProgress?
    
    private var queue = DispatchQueue(
        label: "com.marcuszhou.NineAnimator.model.migrator.CachedDownloadsToAppSupportDataMigrator",
        qos: .userInitiated
    )
    
    // Upgrades app version 1.2.7 Build 5 and below
    var inputVersionRange: Range<NineAnimatorVersion> {
        (.zero)..<(.init(major: 1, minor: 2, patch: 7, build: 6))
    }
    
    func beginMigration(sourceVersion: NineAnimatorVersion) {
        guard currentProgress == nil else {
            return
        }
        
        currentProgress = .init(
            numberOfSteps: 1,
            currentStep: 0,
            currentStepDescription: "Transferring Downloaded Episodes",
            currentStepItemsCount: 0,
            currentStepProcessingItem: 0
        )
        
        // Perform the migration asynchronously
        queue.async {
            self.performMigration(sourceVersion: sourceVersion)
        }
    }
}

private extension CachedDownloadsToAppSupportDataMigrator {
    func performMigration(sourceVersion: NineAnimatorVersion) {
        do {
            Log.info("[CachedDownloadsToDocumentsDataMigrator] Migrating user data from NineAnimator version %@...", sourceVersion)
            
            delegate?.migrator(willBeginMigration: self)
            
            let fs = FileManager.default
            // Retrieve cache directory
            let cacheDirectory = try fs.url(
                for: .cachesDirectory,
                in: .allDomainsMask,
                appropriateFor: nil,
                create: false
            ).appendingPathComponent("com.marcuszhou.nineanimator.OfflineContents")
            
            guard fs.fileExists(atPath: cacheDirectory.path) else {
                Log.debug("[CachedDownloadsToDocumentsDataMigrator] User does not have Offline Contents directory in the cache. No migration required.")
                delegate?.migrator(didCompleteMigration: self, withError: nil)
                return
            }
            
            // Retrieve the new offline contents directory in application support
            let documentsDirectory = try fs.url(
                for: .applicationSupportDirectory,
                in: .allDomainsMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("com.marcuszhou.nineanimator.OfflineContents")
            
            // Create the new directory if it does not exists
            try fs.createDirectory(
                at: documentsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Retrieve path of items to move to the new directory
            let itemsInCache = try fs.contentsOfDirectory(atPath: cacheDirectory.path)
            fireProgressEvent(current: 0, total: itemsInCache.count)
            
            // Move each item to the new directory
            try itemsInCache.forEach { itemPath in
                let newPath = documentsDirectory.appendingPathComponent(itemPath)
                
                // If the item already exists in the new path, override it
                // Under normal circumstances, this should not occur
                // It may occur if the user downgrades and upgrades the app again
                if (try? newPath.checkResourceIsReachable()) == true {
                    Log.error("[CachedDownloadsToDocumentsDataMigrator] Duplicated file detected, removing: %@", newPath)
                    try fs.removeItem(at: newPath)
                }
                
                try fs.moveItem(
                    at: cacheDirectory.appendingPathComponent(itemPath),
                    to: newPath
                )
                fireProgressEvent(total: itemsInCache.count)
            }
            
            // Delete the old directory
            try fs.removeItem(at: cacheDirectory)
            delegate?.migrator(didCompleteMigration: self, withError: nil)
        } catch {
            Log.error("[CachedDownloadsToDocumentsDataMigrator] Error while migrating: %@", error)
            delegate?.migrator(didCompleteMigration: self, withError: error)
        }
    }
    
    func fireProgressEvent(current: Int? = nil, total: Int) {
        if var progress = currentProgress, let delegate = self.delegate {
            progress.currentStepProcessingItem = current ?? progress.currentStepProcessingItem + 1
            progress.currentStepItemsCount = total
            self.currentProgress = progress
            delegate.migrator(migrationInProgress: self, progress: progress)
        }
    }
}
