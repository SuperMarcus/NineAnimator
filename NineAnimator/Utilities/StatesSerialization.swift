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
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources

private struct StateSerializationFile: Codable {
    /// Recent anime list
    var history: [AnimeLink]
    
    /// Progress persistence
    var progresses: [String: Float]
    
    /// Date of generation
    var exportedDate: Date
    
    /// Serialzied `TrackingContext`
    var trackingData: [AnimeLink: Data]?
    
    /// Subscriptions
    var subscriptions: [AnimeLink]?
}

/**
 Creating the .naconfig file for sharing and backing up anime watching
 histories.
 */
func export(_ configuration: NineAnimatorUser) -> URL? {
    do {
        let trackingData: [AnimeLink: Data] = Dictionary(configuration.retrieveRecents().compactMap {
            anime in do {
                let context = NineAnimator.default.trackingContext(for: anime)
                let data = try context.export()
                return (anime, data)
            } catch { Log.error("[Model.export] Unable to serialize tracking data for %@: %@", anime, error) }
            return nil
        }) { newest, _ in
            newest // Only keep the most recent data
        }
        
        let file = StateSerializationFile(
            history: configuration.retrieveRecents(),
            progresses: configuration.persistedProgresses,
            exportedDate: Date(),
            trackingData: trackingData,
            subscriptions: configuration.subscribedAnimes
        )
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM dd yyy HH-mm-ss"
        
        let fileName = "\(formatter.string(from: file.exportedDate)).naconfig"
        let fs = FileManager.default
        let url = fs.temporaryDirectory.appendingPathComponent(fileName)
        
        try PropertyListEncoder().encode(file).write(to: url)
        
        return url
    } catch { Log.error(error) }
    
    return nil
}

func merge(_ configuration: NineAnimatorUser, with fileUrl: URL, policy: NineAnimatorUser.MergePiority) throws {
    // Read the contents of the configuration file
    // Normally we would check if this function call return true to determine
    // if it succeeded, however it creates false negatives, so we only log it.
    if fileUrl.startAccessingSecurityScopedResource() == false {
        Log.error("Failed to gain access to security scoped resource. Ignoring for now. URL: %@", fileUrl.absoluteString)
    }
    let serializedConfiguration = try Data(contentsOf: fileUrl)
    fileUrl.stopAccessingSecurityScopedResource()
    
    let preservedStates = try PropertyListDecoder().decode(StateSerializationFile.self, from: serializedConfiguration)
    
    let piorityHistory = policy == .localFirst ? configuration.retrieveRecents() : preservedStates.history
    let secondaryHistory = policy == .localFirst ? preservedStates.history : configuration.retrieveRecents()
    
    configuration.setRecents(to: piorityHistory + secondaryHistory.filter {
        item in !piorityHistory.contains { $0 == item }
    })
    
    let piroityPersistedProgresses = policy == .localFirst ? configuration.persistedProgresses : preservedStates.progresses
    let secondaryPersistedProgresses = policy == .localFirst ? preservedStates.progresses : configuration.persistedProgresses
    
    configuration.persistedProgresses = piroityPersistedProgresses
        .merging(secondaryPersistedProgresses) { piority, _ in piority }
    
    // Merge subscription list
    if let backupSubscriptions = preservedStates.subscriptions {
        var finalSubscriptionsSet = Set<AnimeLink>()
        configuration.subscribedAnimes.forEach { finalSubscriptionsSet.insert($0) }
        backupSubscriptions.forEach { finalSubscriptionsSet.insert($0) }
        configuration.subscribedAnimes = finalSubscriptionsSet.map { $0 }
    }
}

func replace(_ configuration: NineAnimatorUser, with fileUrl: URL) throws {
    // Read the contents of the configuration file
    // Normally we would check if this function call return true to determine
    // if it succeeded, however it creates false negatives, so we only log it.
    if fileUrl.startAccessingSecurityScopedResource() == false {
        Log.error("Failed to gain access to security scoped resource. Ignoring for now. URL: %@", fileUrl.absoluteString)
    }
    let serializedConfiguration = try Data(contentsOf: fileUrl)
    fileUrl.stopAccessingSecurityScopedResource()
    
    let preservedStates = try PropertyListDecoder().decode(StateSerializationFile.self, from: serializedConfiguration)
    
    configuration.setRecents(to: preservedStates.history)
    configuration.persistedProgresses = preservedStates.progresses
    
    // Restoring subscription list
    if let subscriptions = preservedStates.subscriptions {
        configuration.subscribedAnimes = subscriptions
    }
    
    // Restoring the tracking data
    if let trackingData = preservedStates.trackingData {
        for (anime, data) in trackingData {
            do {
                let context = NineAnimator.default.trackingContext(for: anime)
                try context.restore(from: data)
                context.save()
            } catch { Log.error("[Model.replace] Unable to restore %@: %@", anime, data) }
        }
    }
}
