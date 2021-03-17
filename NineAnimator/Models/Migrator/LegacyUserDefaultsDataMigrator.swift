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

class LegacyUserDefaultsModelMigrator: ModelMigrator {
    weak var delegate: ModelMigratorDelegate?
    
    private var currentProgress: ModelMigrationProgress?
    
    private var queue = DispatchQueue(
        label: "com.marcuszhou.NineAnimator.model.migrator.LegacyUserDefaultsModelMigrator",
        qos: .userInitiated
    )
    
    /// Accepts version up to 1.2.6-15
    var inputVersionRange: Range<NineAnimatorVersion> {
        (.zero)..<(.init(major: 1, minor: 2, patch: 7, build: 2))
    }
    
    func beginMigration(sourceVersion: NineAnimatorVersion) {
        guard currentProgress == nil else {
            return
        }
        
        currentProgress = .init(
            numberOfSteps: 1,
            currentStep: 0,
            currentStepDescription: "",
            currentStepItemsCount: 0,
            currentStepProcessingItem: 0
        )
        
        // Perform the migration asynchronously
        queue.async {
            self.performMigration(sourceVersion: sourceVersion)
        }
    }
}

private extension LegacyUserDefaultsModelMigrator {
    func performMigration(sourceVersion: NineAnimatorVersion) {
        do {
            Log.info("[LegacyUserDefaultsModelMigrator] Migrating user data from NineAnimator version %@...", sourceVersion)
            
            delegate?.migrator(willBeginMigration: self)
            
            let sourceSuite = UserDefaults.standard
            let coreDataLibrary = NineAnimator.default.user.coreDataLibrary
            let migrationContext = coreDataLibrary.createBackgroundContext()
            
            currentProgress?.currentStep = 0
            currentProgress?.currentStepDescription = "Migrating Recents..."
            try migrateRecentRecords(suite: sourceSuite, destination: migrationContext)
            
            delegate?.migrator(didCompleteMigration: self, withError: nil)
        } catch {
            Log.error("[LegacyUserDefaultsModelMigrator] Error while migrating: %@", error)
            delegate?.migrator(didCompleteMigration: self, withError: error)
        }
    }
    
    func migrateRecentRecords(suite source: UserDefaults, destination context: NACoreDataLibrary.Context) throws {
        if let propertyEncodedRecentsData = source.data(forKey: MigrateKeys.recentAnimeList) {
            let decodedRecents = try PropertyListDecoder().decode(
                [AnimeLink].self,
                from: propertyEncodedRecentsData
            )
            
            fireProgressEvent(current: 0, total: decodedRecents.count)
            try context.resetRecents(to: decodedRecents.map {
                .anime($0)
            })
            fireProgressEvent(current: decodedRecents.count, total: decodedRecents.count)
        }
    }
    
    func fireProgressEvent(current: Int, total: Int) {
        if var progress = currentProgress, let delegate = self.delegate {
            progress.currentStepProcessingItem = current
            progress.currentStepItemsCount = total
            self.currentProgress = progress
            delegate.migrator(migrationInProgress: self, progress: progress)
        }
    }
}

private extension LegacyUserDefaultsModelMigrator {
    enum MigrateKeys {
        static var recentAnimeList: String { "anime.recent" }
        static var subscribedAnimeList: String { "anime.subscribed" }
        static var allowNSFWContent: String { "anime.content.nsfw" }
        static var animeInformationSource: String { "anime.details.source" }
        static var recentEpisode: String { "episode.recent" }
        static var recentSource: String { "source.recent" }
        static var searchHistory: String { "history.search" }
        static var recentServer: String { "server.recent" }
        static var persistedProgresses: String { "episode.progress" }
    }
}
