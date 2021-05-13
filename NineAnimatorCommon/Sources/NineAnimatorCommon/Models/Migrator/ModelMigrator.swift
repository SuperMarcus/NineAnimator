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

public protocol ModelMigrator: AnyObject {
    var delegate: ModelMigratorDelegate? { get set }
    
    /// The input version range that the migrator accepts
    var inputVersionRange: Range<NineAnimatorVersion> { get }
    
    /// Perform the migration asynchronously
    func beginMigration(sourceVersion: NineAnimatorVersion)
}

/// Progress of data migration
public struct ModelMigrationProgress {
    /// Total number of steps for this migration
    public var numberOfSteps: Int
    
    /// Current step that the migrator is performing
    public var currentStep: Int
    
    /// User-readable description of the current step
    public var currentStepDescription: String
    
    /// Number of items in the current step
    public var currentStepItemsCount: Int
    
    /// Index of the currently processing item
    public var currentStepProcessingItem: Int
}

/// Delegate for ModelMigrator.
///
/// - Note: ModelMigrator makes no promise on which thread the delegate methods are called.
public protocol ModelMigratorDelegate: AnyObject {
    func migrator(willBeginMigration migrator: ModelMigrator)
    func migrator(migrationInProgress migrator: ModelMigrator, progress: ModelMigrationProgress)
    func migrator(didCompleteMigration migrator: ModelMigrator, withError error: Error?)
}
